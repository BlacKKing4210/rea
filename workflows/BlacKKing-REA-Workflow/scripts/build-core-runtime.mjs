#!/usr/bin/env node
/** Build the fork's verified production archive; never copy its development tree. */
import { constants } from "node:fs";
import {
  access, copyFile, lstat, mkdir, readFile, realpath, rm, stat, writeFile,
} from "node:fs/promises";
import { createHash, randomUUID } from "node:crypto";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const hash = async (path) => createHash("sha256").update(await readFile(path)).digest("hex");
const within = (parent, child) => {
  const value = relative(parent, child);
  return value === "" || (!isAbsolute(value) && value !== ".." && !value.startsWith(`..${sep}`));
};
const absent = async (path) => {
  try { await lstat(path); } catch (error) {
    if (error.code === "ENOENT") return;
    throw error;
  }
  throw new Error(`Existing path preserved; refusing overwrite: ${path}`);
};

export function parseOptions(args) {
  const options = {};
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index]?.replace(/^--/u, "").toLowerCase();
    if (!args[index]?.startsWith("--") || !["root", "output", "workspace", "python"].includes(key)
        || args[index + 1] === undefined || args[index + 1].startsWith("--") || Object.hasOwn(options, key))
      throw new Error("Usage: --Root SOURCE --Output ARCHIVE.tgz --Workspace NEW_DIRECTORY [--Python EXECUTABLE]");
    options[key] = args[index + 1];
  }
  if (!["root", "output", "workspace"].every((key) => options[key]))
    throw new Error("Root, Output and Workspace are required");
  return { root: resolve(options.root), output: resolve(options.output),
    workspace: resolve(options.workspace), python: options.python ?? "python3" };
}

export async function buildCoreRuntime(options) {
  const { root, output, workspace, python } = options;
  const receiptPath = `${output}.json`;
  if (within(workspace, root) || within(workspace, output))
    throw new Error("Workspace must not contain the source or final output");
  await absent(output);
  await absent(receiptPath);
  await absent(workspace);
  const packageJson = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
  const lock = JSON.parse(await readFile(join(root, "package-lock.json"), "utf8"));
  if (packageJson.name !== "rea-agents" || packageJson.version !== lock.version)
    throw new Error("Root must be the matching REA fork source and lock");
  const nodePin = (await readFile(join(root, ".nvmrc"), "utf8")).trim();
  if (process.versions.node !== nodePin)
    throw new Error(`Build with the source-pinned Node ${nodePin}; found ${process.versions.node}`);
  if (!process.env.npm_execpath) throw new Error("Set process-only npm_execpath to the pinned npm CLI");
  const npmEntry = resolve(process.env.npm_execpath);
  const npmJson = JSON.parse(await readFile(join(dirname(npmEntry), "..", "package.json"), "utf8"));
  if (`npm@${npmJson.version}` !== packageJson.packageManager)
    throw new Error(`Build requires ${packageJson.packageManager}; found npm@${npmJson.version}`);

  const sourceFiles = ["package.json", "package-lock.json", ".nvmrc",
    "scripts/verify-package-pack.mjs", "scripts/lib/plugin-package.mjs",
    "scripts/verify-packed-bridge.mjs", "dist/generatedPackageMetadata.js",
    "native/windows/build/manifest.json", "native/windows/build/rea-windows-x64.node"];
  const sourceHashes = Object.fromEntries(await Promise.all(sourceFiles.map(async (name) => [name, await hash(join(root, name))])));
  // The exact new leaf is owned by this run; a caller's pre-existing directory
  // can never be adopted or recursively removed.
  await mkdir(dirname(workspace), { recursive: true });
  await mkdir(workspace);
  const owner = { token: randomUUID(), root, output, workspace };
  const marker = join(workspace, ".blackking-core-owner.json");
  await writeFile(marker, JSON.stringify(owner), { flag: "wx" });
  const identity = await lstat(workspace);
  const canonicalWorkspace = await realpath(workspace);
  let complete = false;
  let cleanup = "PRESERVED_PENDING_COMPLETION";
  let commands;
  let failure;
  let result;
  const closeWorkspace = async () => {
    if (!complete) { cleanup = "PRESERVED_ON_FAILURE"; return; }
    const current = await lstat(workspace);
    const saved = JSON.parse(await readFile(marker, "utf8"));
    if (current.isSymbolicLink() || current.dev !== identity.dev || current.ino !== identity.ino
        || await realpath(workspace) !== canonicalWorkspace || saved.token !== owner.token)
      throw new Error(`Owned cleanup identity changed; workspace preserved: ${workspace}`);
    await rm(canonicalWorkspace, { recursive: true, force: false });
    cleanup = "EXACT_OWNED_WORKSPACE_REMOVED";
  };
  try {
    const { createPackageVerifierCommands } = await import(pathToFileURL(join(root, "scripts/lib/verify-package-commands.mjs")));
    commands = await createPackageVerifierCommands({ workspace: { path: workspace, close: closeWorkspace } });
    const isolatedHome = join(workspace, "verification-home");
    await mkdir(isolatedHome);
    const isolatedEnvironment = { ...process.env, HOME: isolatedHome, USERPROFILE: isolatedHome,
      CODEX_HOME: join(isolatedHome, ".codex"), XDG_CONFIG_HOME: join(isolatedHome, "config"),
      XDG_CACHE_HOME: join(isolatedHome, "cache"), APPDATA: join(isolatedHome, "roaming"),
      LOCALAPPDATA: join(isolatedHome, "local"), REA_LOG_LEVEL: "silent" };
    const delegated = {
      execNpm: (...args) => commands.execNpm(...args),
      exec: (command, args, settings) => commands.exec(command === "python3" ? python : command, args, settings),
    };
    const { verifyPackagePack } = await import(pathToFileURL(join(root, "scripts/verify-package-pack.mjs")));
    process.stderr.write("Building verified production dependency archive from current source...\n");
    const { tarball } = await verifyPackagePack({ root, workspace, commands: delegated });
    const stage = join(workspace, "plugin-package");
    const stagedJson = JSON.parse(await readFile(join(stage, "package.json"), "utf8"));
    const bundled = stagedJson.bundleDependencies;
    if (!Array.isArray(bundled) || bundled.length !== Object.keys(packageJson.dependencies).length)
      throw new Error("Production runtime dependency bundle is incomplete");
    for (const dependency of bundled) await access(join(stage, "node_modules", dependency, "package.json"));
    const requiredLicenses = ["LICENSE", "THIRD_PARTY_NOTICES.md", "licenses/npm-dependencies.txt",
      "licenses/npm-runtime-notices.txt", "licenses/upstream-sources.json",
      "licenses/MinGW-w64-runtime.txt", "licenses/GPL-3.0.txt", "licenses/GCC-Runtime-Library-Exception-3.1.txt"];
    const licenseFiles = await Promise.all(requiredLicenses.map(async (path) => ({ path, sha256: await hash(join(stage, path)) })));
    const native = await commands.exec(process.execPath, [join(stage, "scripts/verify-windows-native-artifact.mjs")],
      { cwd: stage, env: isolatedEnvironment });
    const cli = await commands.exec(process.execPath, [join(stage, "scripts/rea.mjs"), "--version"],
      { cwd: stage, env: isolatedEnvironment });
    if (!cli.stdout.includes(packageJson.version)) throw new Error("Staged CLI module load/version failed");
    for (const [path, digest] of Object.entries(sourceHashes))
      if (await hash(join(root, path)) !== digest) throw new Error(`Source changed during packaging; preserved: ${path}`);
    await mkdir(dirname(output), { recursive: true });
    await copyFile(tarball, output, constants.COPYFILE_EXCL);
    const archiveHash = await hash(output);
    if (archiveHash !== await hash(tarball)) throw new Error("Published archive copy hash mismatch; preserve for review");
    result = {
      schema: "blackking-rea-core-runtime/v1", utc: new Date().toISOString(), status: "PASS_VERIFIED_CORE_ARCHIVE",
      package: packageJson.name, version: packageJson.version, platform: process.platform, architecture: process.arch,
      node: process.versions.node, npm: npmJson.version, output, bytes: (await stat(output)).size, sha256: archiveHash,
      builder_sha256: await hash(fileURLToPath(import.meta.url)), source_hashes: sourceHashes,
      runtime_direct_dependencies_bundled: bundled.length, runtime_dependency_names: bundled,
      native_verification: JSON.parse(native.stdout), cli_version_output: cli.stdout.trim(), license_files: licenseFiles,
      verification_python: python, source_checkout_copied: false, development_node_modules_copied: false,
      production_dependencies_materialized_from_lock: true, paid: false, game_data_included: false,
      boundaries: ["Core archive excludes Node runtime; final migration package supplies it separately.",
        "Optional Frida and user-supplied analysis engines are not established by core packaging.",
        "Checks cover current archive/dependencies/CLI module load/native bytes/licenses; final relocated CLI/MCP QA remains."],
    };
    complete = true;
  } catch (error) { failure = error; }
  try {
    if (commands) await commands.close();
    else if (complete) await closeWorkspace();
  } catch (error) { cleanup = "PRESERVED_CLEANUP_FAILED"; failure = error; }
  if (failure) {
    const failed = { schema: "blackking-rea-core-runtime-failure/v1", utc: new Date().toISOString(),
      status: "FAILED_PRESERVED", workspace, output, cleanup, error: String(failure) };
    await writeFile(join(workspace, "failure.json"), JSON.stringify(failed, null, 2), { flag: "wx" }).catch(() => {});
    throw Object.assign(failure, { buildReceipt: failed });
  }
  result.cleanup = cleanup;
  await writeFile(receiptPath, JSON.stringify(result, null, 2), { flag: "wx" });
  return { ...result, receipt: receiptPath };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(await buildCoreRuntime(parseOptions(process.argv.slice(2))))); }
  catch (error) {
    console.error(JSON.stringify(error.buildReceipt ?? { status: "REFUSED", error: String(error) }));
    process.exitCode = 1;
  }
}
