"""Filesystem maintenance for structured CI diagnostics."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from ci_ui_retry import recovery_valid
from internal.output_retention import KEEP, expire_results, process_snapshot, protection, safe_path


def require_results_dir(value: str) -> Path:
    original = Path(value).absolute()
    if not safe_path(original, original):
        raise SystemExit("refusing a symlinked TestResults directory")
    root = original.resolve()
    if root.name != "TestResults" or not root.is_dir():
        raise SystemExit("refusing to operate outside an explicit TestResults directory")
    return root


def remove(path: Path) -> bool:
    """Remove one artifact path; True when something was actually deleted."""
    if path.is_symlink():
        path.unlink()
        return True
    if path.is_dir():
        shutil.rmtree(path)
        return True
    if path.is_file():
        path.unlink()
        return True
    return False


def reset(root: Path) -> None:
    for path in root.iterdir():
        if path.is_file() and (
            path.name.endswith(("-diagnostics.json", "-diagnostics.md", "-diagnostics.annotations", "-invocation.json"))
            or path.name in {"ci-diagnostics.json", "phase-timing.jsonl"}
        ):
            remove(path)
        elif path.is_dir() and path.name.endswith("-diagnostics.attachments"):
            remove(path)
    print(f"Cleared prior CI diagnostic/status artifacts in {root}")


def prepare_artifact_dir(root: Path, artifact_dir: Path) -> None:
    root = root.resolve()
    destination = artifact_dir.resolve()
    if destination == root or destination in root.parents or root in destination.parents:
        raise SystemExit("artifact directory must not overlap TestResults")
    shutil.rmtree(artifact_dir, ignore_errors=True)
    artifact_dir.mkdir(parents=True, exist_ok=True)


def stage_gate(root: Path, artifact_dir: Path) -> None:
    prepare_artifact_dir(root, artifact_dir)
    # Gate logs have no invocation manifests. Keep complete small reports and
    # both ends of large logs, with a fixed aggregate bound for hosted uploads.
    maximum_file_bytes = 1024 * 1024
    policy = (
        'Gate diagnostics: at most 128 files, 1 MiB per file, 16 MiB total; '
        'large files retain their beginning and end.\n'
    ).encode()
    remaining_bytes = 16 * maximum_file_bytes - len(policy)
    paths = [root / 'gate.log']
    paths += sorted(root.glob('script-tests.*/*'))
    for path in paths[:127]:
        if path.is_symlink() or not path.is_file() or path.parent.is_symlink():
            continue
        budget = min(maximum_file_bytes, remaining_bytes)
        if budget < 1024:
            break
        with path.open('rb') as stream:
            if path.stat().st_size > budget:
                marker = b'\n... diagnostic middle omitted by artifact size budget ...\n'
                half = (budget - len(marker)) // 2
                content = stream.read(half)
                stream.seek(-half, 2)
                content += marker + stream.read(half)
            else:
                content = stream.read(budget)
        target = artifact_dir / path.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        remaining_bytes -= len(content)
    (artifact_dir / 'artifact-policy.txt').write_bytes(policy)
    print(f'Staged bounded gate diagnostics in {artifact_dir}')


def stage(root: Path, artifact_dir: Path) -> None:
    prepare_artifact_dir(root, artifact_dir)
    category_path = root / "ci-diagnostics.json"
    try:
        payload = json.loads(category_path.read_text(encoding="utf-8"))
        category = payload.get("category", "unknown") if isinstance(payload, dict) else "unknown"
    except (OSError, json.JSONDecodeError):
        category = "unknown"
    names = {"ci-diagnostics.json", "timing-log.jsonl", "simulator.log", "phase-timing.jsonl"}
    for path in root.iterdir():
        if path.is_file() and (path.name in names or path.name.endswith(("-invocation.json", "-diagnostics.json", "-diagnostics.md", "-diagnostics.annotations"))):
            shutil.copy2(path, artifact_dir / path.name)
    if category != "passed":
        source = root / "raw"
        if source.is_dir():
            shutil.copytree(source, artifact_dir / "raw")
        for path in root.glob("*.xcresult"):
            shutil.copytree(path, artifact_dir / path.name)
        for path in root.glob("*-diagnostics.attachments"):
            shutil.copytree(path, artifact_dir / path.name)
        (artifact_dir / "artifact-policy.txt").write_text(f"full forensic artifacts retained because category={category}\n")
    else:
        (artifact_dir / "artifact-policy.txt").write_text("structured artifacts only; raw logs and xcresults omitted for passing invocations\n")
    print(f"Staged CI artifacts in {artifact_dir} (category={category})")


def artifact_path(value: object, root: Path) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    path = Path(value).expanduser().absolute()
    return path if path.resolve() != root.resolve() and safe_path(path, root) else None


def cleanup(root: Path, keep: bool) -> None:
    if keep:
        if (root / KEEP).is_symlink():
            raise SystemExit("refusing a symlinked keep control")
        (root / KEEP).touch()
        print(f"Keeping diagnostic artifacts in {root} (--keep)")
        return
    if (root / KEEP).exists():
        print(f"Keeping explicitly retained diagnostic artifacts in {root}")
        return
    processes = process_snapshot()
    removed = 0
    manifests = {}
    recovered = set()
    # Validate paired recovery before deleting either invocation's evidence.
    # Unrecovered failures keep their forensic artifacts as before.
    for path in root.glob("*-invocation.json"):
        try:
            manifest = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(manifest, dict):
                continue
            manifests[path] = manifest
            if manifest.get("infrastructure_recovery"):
                report = json.loads(Path(manifest["diagnostics_json"]).read_text())
                if recovery_valid(manifest, report):
                    recovered.add(path)
        except (OSError, ValueError, KeyError, TypeError):
            continue
    for manifest_path, manifest in manifests.items():
        exit_code = manifest.get("exit_code")
        passed = manifest.get("status") == "passed" and type(exit_code) is int and exit_code == 0
        if not passed and manifest_path not in recovered:
            continue
        artifacts = set()
        if manifest.get('action') == 'native-test':
            for value in manifest.get('native_artifacts', []):
                native = artifact_path(value, root)
                if native is not None:
                    artifacts.add(native)
        result = artifact_path(manifest.get("result_bundle"), root)
        if result is not None:
            stem = result.name.removesuffix(".xcresult")
            artifacts.update((result, root / "raw" / f"{stem}.log", root / f"{stem}-diagnostics.attachments"))
        report = artifact_path(manifest.get("diagnostics_json"), root)
        if report is not None:
            artifacts.update((report, report.with_suffix(".md"), report.with_suffix(".annotations"),
                              report.with_name(report.name.removesuffix(".json") + ".attachments")))
        if any(protection(path, root, processes) for path in artifacts | {manifest_path}):
            continue
        removed += sum(remove(path) for path in sorted(artifacts))
        removed += remove(manifest_path)
    if not list(root.glob("*-invocation.json")):
        if remove(root / "ci-diagnostics.json"):
            removed += 1
    expired, _ = expire_results(root)
    print(f"Cleaned {removed} successful diagnostic artifact(s) and {expired} expired output(s) from {root}")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        raise SystemExit("Usage: diagnostic_maintenance.py <reset|stage|stage-gate|cleanup> RESULTS_DIR [ARTIFACT_DIR] [--keep]")
    mode = argv[0]
    root = require_results_dir(argv[1])
    if mode == "reset":
        reset(root)
    elif mode in ("stage", "stage-gate"):
        if len(argv) < 3 or not argv[2]:
            raise SystemExit("stage requires an artifact directory")
        stager = stage_gate if mode == "stage-gate" else stage
        stager(root, Path(argv[2]).resolve())
    elif mode == "cleanup":
        cleanup(root, "--keep" in argv[2:])
    else:
        raise SystemExit(f"unknown maintenance mode: {mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
