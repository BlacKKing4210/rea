"""Assemble an explicit, hash-verified Windows REA workflow distribution.

No downloads, case scanning, tool installation, or account/configuration writes.
The new staging directory is a reviewable local portable installation; keep it
fixed if an explicit installer later registers its MCP entry.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tarfile
import zipfile


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def plain(path):
    path = path.absolute()
    for item in (path, *path.parents):
        if item.exists() or item.is_symlink():
            info = item.lstat()
            if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
                raise ValueError(f"Reparse/link path refused: {item}")
    # Check the original spelling first: resolving before lstat could hide a
    # junction in a component followed by '..'. Containment then uses one
    # normalized representation, including for destinations not yet created.
    return path.resolve(strict=False)


def logical(name):
    if not isinstance(name, str) or not name or "\\" in name or re.search(r'[<>:"|?*\x00-\x1f]', name):
        raise ValueError(f"Unsafe archive name: {name!r}")
    path = PurePosixPath(name)
    if path.is_absolute() or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError(f"Unsafe archive path: {name!r}")
    for part in path.parts:
        if part.endswith((".", " ")) or re.match(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)", part, re.I):
            raise ValueError(f"Unsafe Windows archive path: {name!r}")
    return path


def copy_new(source, destination):
    plain(source)
    if not source.is_file():
        raise ValueError(f"Source is not a regular file: {source}")
    plain(destination.parent)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as incoming, destination.open("xb") as outgoing:
        shutil.copyfileobj(incoming, outgoing)
    if sha(source) != sha(destination):
        raise ValueError(f"Copy hash mismatch: {destination}")


def project_members(entries, prefix):
    """Validate all names and kinds before extracting any member."""
    names = set()
    projected = []
    for name, is_dir, is_file, entry in entries:
        name = name.rstrip("/")
        path = logical(name)
        if path.parts[0] != prefix:
            raise ValueError(f"Unexpected archive root: {name}")
        if len(path.parts) == 1:
            if not is_dir:
                raise ValueError("Archive root must be a directory")
            continue
        relative = PurePosixPath(*path.parts[1:]).as_posix()
        if relative.casefold() in names:
            raise ValueError(f"Case-colliding/duplicate member: {name}")
        names.add(relative.casefold())
        if not is_dir and not is_file:
            raise ValueError(f"Link or special member refused: {name}")
        projected.append((relative, is_dir, entry))
    return projected


def extract_node(archive, destination):
    with zipfile.ZipFile(archive) as incoming:
        members = project_members(
            [(x.filename, x.is_dir(), not x.is_dir() and stat.S_IFMT(x.external_attr >> 16) != stat.S_IFLNK, x)
             for x in incoming.infolist()], "node-v24.22.1-win-x64")
        for name, is_dir, item in members:
            target = destination.joinpath(*PurePosixPath(name).parts)
            if is_dir:
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with incoming.open(item) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)


def extract_core(archive, destination):
    with tarfile.open(archive, "r:gz") as incoming:
        members = project_members(
            [(x.name, x.isdir(), x.isfile(), x) for x in incoming.getmembers()], "package")
        for name, is_dir, item in members:
            target = destination.joinpath(*PurePosixPath(name).parts)
            if is_dir:
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with incoming.extractfile(item) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)


def inventory(root):
    rows = []
    for path in sorted(root.rglob("*")):
        plain(path)
        if path.is_file() and path.name != "package-manifest.json":
            name = path.relative_to(root).as_posix()
            logical(name)
            rows.append({"path": name, "bytes": path.stat().st_size, "sha256": sha(path)})
    return rows


def closure(rows):
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def write_archive(stage, output, manifest):
    part = output.with_name(output.name + ".part")
    if output.exists() or part.exists():
        raise ValueError("Output or partial exists; preserve it instead of overwriting")
    plain(output.parent)
    if not output.parent.is_dir():
        raise ValueError("Create the explicit output parent first")
    with zipfile.ZipFile(part, "x", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
        for row in manifest["files"]:
            path = stage.joinpath(*PurePosixPath(row["path"]).parts)
            if path.stat().st_size != row["bytes"] or sha(path) != row["sha256"]:
                raise ValueError(f"Staging input drift: {row['path']}")
            archive.write(path, row["path"])
        archive.write(stage / "package-manifest.json", "package-manifest.json")
    with zipfile.ZipFile(part) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC check failed")
        expected = {row["path"]: row for row in manifest["files"]}
        if len(archive.infolist()) != len(expected) + 1:
            raise ValueError("Archive member count mismatch")
        for name, row in expected.items():
            with archive.open(name) as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != row["sha256"] or archive.getinfo(name).file_size != row["bytes"]:
                raise ValueError(f"Archive member hash mismatch: {name}")
        if archive.read("package-manifest.json") != (stage / "package-manifest.json").read_bytes():
            raise ValueError("Archive manifest mismatch")
    part.rename(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--core-tar", required=True, type=Path)
    parser.add_argument("--core-sha256", required=True)
    parser.add_argument("--node-zip", required=True, type=Path)
    parser.add_argument("--stage", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--stage-only", action="store_true")
    parser.add_argument("--seal-existing-stage", action="store_true")
    args = parser.parse_args()
    root = plain(args.repo_root).resolve(strict=True)
    workflow = root / "workflows/BlacKKing-REA-Workflow"
    spec = json.loads((workflow / "bundle-spec.json").read_text(encoding="utf-8"))
    stage, output = plain(args.stage), plain(args.output)
    for path in (stage, output):
        if path.is_relative_to(root):
            raise ValueError("Generated artifacts must stay outside the source repository")
    if output.exists() or output.with_name(output.name + ".part").exists():
        raise ValueError("Output exists; preserve it")
    if args.seal_existing_stage:
        manifest = json.loads((stage / "package-manifest.json").read_text(encoding="utf-8"))
        if manifest["name"] != spec["name"] or manifest["version"] != spec["version"]:
            raise ValueError("Wrong staged bundle identity")
        actual = inventory(stage)
        if actual != manifest["files"] or closure(actual) != manifest["package_input_closure_sha256"]:
            raise ValueError("Existing stage has changed; re-prepare reviewed inputs")
        for name in spec["workflow_files"]:
            if sha(workflow / name) != sha(stage / name):
                raise ValueError(f"Authored workflow changed after staging: {name}")
        write_archive(stage, output, manifest)
    else:
        if stage.exists():
            raise ValueError("Staging path exists; preserve it")
        if not stage.parent.is_dir():
            raise ValueError("Create the explicit staging parent first")
        for path in (args.core_tar, args.node_zip):
            plain(path)
        if not re.fullmatch(r"[a-f0-9]{64}", args.core_sha256) or sha(args.core_tar) != args.core_sha256:
            raise ValueError("Core archive hash mismatch")
        if sha(args.node_zip) != spec["node_archive_sha256"]:
            raise ValueError("Official Node archive hash mismatch")
        for name in spec["workflow_files"]:
            logical(name)
            plain(workflow / name)
            if not (workflow / name).is_file():
                raise ValueError(f"Missing authored workflow file: {name}")
        stage.mkdir()
        for name in spec["workflow_files"]:
            copy_new(workflow / name, stage / name)
        extract_node(args.node_zip, stage / "runtime/node")
        extract_core(args.core_tar, stage / "runtime/rea")
        if sha(stage / "runtime/node/node.exe") != spec["node_executable_sha256"]:
            raise ValueError("Bundled Node executable differs from official checksum")
        package = json.loads((stage / "runtime/rea/package.json").read_text(encoding="utf-8"))
        if package["name"] != spec["rea_package"] or package["version"] != spec["rea_version"]:
            raise ValueError("Wrong REA core identity")
        if not package.get("bundleDependencies"):
            raise ValueError("REA runtime is not the dependency-complete production bundle")
        for name in ("runtime/rea/LICENSE", "runtime/rea/THIRD_PARTY_NOTICES.md", "runtime/node/LICENSE"):
            if not (stage / name).is_file():
                raise ValueError(f"Required license missing: {name}")
        (stage / "source").mkdir()
        source_zip = stage / "source/rea-source.zip"
        subprocess.run(["git", "-C", str(root), "archive", "--format=zip", "--prefix=rea/",
                        "--output=" + str(source_zip), spec["rea_core_source_commit"]], check=True)
        rows = inventory(stage)
        manifest = {"schema": "blackking-rea-portable-bundle/v1", "name": spec["name"],
                    "version": spec["version"], "platform": spec["platform"],
                    "rea_core_source_commit": spec["rea_core_source_commit"],
                    "rea_repository": spec["rea_repository"], "node_version": spec["node_version"],
                    "node_archive_sha256": spec["node_archive_sha256"],
                    "core_archive_sha256": args.core_sha256,
                    "case_material_included": False, "credentials_or_machine_config_included": False,
                    "analysis_engines_included": False, "paid_services_required": False,
                    "files": rows, "package_input_closure_sha256": closure(rows)}
        (stage / "package-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if not args.stage_only:
            write_archive(stage, output, manifest)
    result = {"status": "STAGED_PENDING_RELOCATED_VERIFICATION" if args.stage_only else "ZIP_BYTE_VERIFIED",
              "files": len(manifest["files"]) + 1,
              "uncompressed_bytes": sum(row["bytes"] for row in manifest["files"]),
              "package_input_closure_sha256": manifest["package_input_closure_sha256"],
              "zip": str(output) if not args.stage_only else None,
              "zip_sha256": sha(output) if not args.stage_only else None,
              "zip_bytes": output.stat().st_size if not args.stage_only else None}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
