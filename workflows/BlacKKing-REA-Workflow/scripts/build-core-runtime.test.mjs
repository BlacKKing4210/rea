import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { buildCoreRuntime, parseOptions } from "./build-core-runtime.mjs";

test("portable arguments are explicit and unknown/duplicate arguments refuse", () => {
  const parsed = parseOptions(["--Root", ".", "--Output", "core.tgz", "--Workspace", "fresh", "--Python", "python"]);
  assert.equal(parsed.python, "python");
  assert.throws(() => parseOptions(["--Root", "."]));
  assert.throws(() => parseOptions(["--Root", ".", "--Root", "other"]));
  assert.throws(() => parseOptions(["--unknown", "value"]));
});

test("pre-existing outputs/workspaces are preserved before any production action", async () => {
  const fixture = await mkdtemp(join(process.env.REA_WORKFLOW_TEST_ROOT ?? tmpdir(), "core-guards-"));
  const output = join(fixture, "existing.tgz");
  const workspace = join(fixture, "work");
  const root = join(fixture, "source-does-not-exist");
  try {
    await writeFile(output, "KEEP_OUTPUT");
    await assert.rejects(buildCoreRuntime({ root, output, workspace, python: "python3" }), /Existing path preserved/u);
    assert.equal(await readFile(output, "utf8"), "KEEP_OUTPUT");
    await mkdir(workspace);
    await writeFile(join(workspace, "user.txt"), "KEEP_WORKSPACE");
    await assert.rejects(buildCoreRuntime({ root, output: join(fixture, "new.tgz"), workspace, python: "python3" }), /Existing path preserved/u);
    assert.equal(await readFile(join(workspace, "user.txt"), "utf8"), "KEEP_WORKSPACE");
    await assert.rejects(buildCoreRuntime({ root, output: join(workspace, "inside.tgz"), workspace, python: "python3" }), /Workspace must not contain/u);
  } finally {
    // This test created the exact fresh leaf; it contains only its sentinels.
    await rm(fixture, { recursive: true, force: false });
  }
});
