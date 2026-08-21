"""Filesystem maintenance for structured CI diagnostics."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


def require_results_dir(value: str) -> Path:
    root = Path(value).resolve()
    if root.name != "TestResults" or not root.is_dir():
        raise SystemExit("refusing to operate outside an explicit TestResults directory")
    return root


def remove(path: Path, count: list[int]) -> None:
    if path.is_dir():
        shutil.rmtree(path)
        count[0] += 1
    elif path.is_file():
        path.unlink()
        count[0] += 1


def reset(root: Path) -> None:
    for path in root.iterdir():
        if path.is_file() and (
            path.name.endswith(("-diagnostics.json", "-diagnostics.md", "-diagnostics.annotations", "-invocation.json"))
            or path.name == "ci-diagnostics.json"
        ):
            path.unlink()
        elif path.is_dir() and path.name.endswith("-diagnostics.attachments"):
            shutil.rmtree(path)
    print(f"Cleared prior CI diagnostic/status artifacts in {root}")


def stage(root: Path, artifact_dir: Path) -> None:
    category_path = root / "ci-diagnostics.json"
    try:
        category = json.loads(category_path.read_text(encoding="utf-8")).get("category", "unknown")
    except (OSError, json.JSONDecodeError):
        category = "unknown"
    if artifact_dir.resolve() in {root, Path("/")}:
        raise SystemExit("artifact directory must be distinct from TestResults")
    shutil.rmtree(artifact_dir, ignore_errors=True)
    artifact_dir.mkdir(parents=True, exist_ok=True)
    names = {"ci-diagnostics.json", "timing-log.jsonl"}
    for path in root.iterdir():
        if path.is_file() and (path.name in names or path.name.endswith(("-invocation.json", "-diagnostics.json", "-diagnostics.md", "-diagnostics.annotations"))):
            shutil.copy2(path, artifact_dir / path.name)
    if category != "passed":
        for name in ("raw",):
            source = root / name
            if source.is_dir():
                shutil.copytree(source, artifact_dir / name)
        for path in root.glob("*.xcresult"):
            shutil.copytree(path, artifact_dir / path.name)
        for path in root.glob("*-diagnostics.attachments"):
            shutil.copytree(path, artifact_dir / path.name)
        (artifact_dir / "artifact-policy.txt").write_text(f"full forensic artifacts retained because category={category}\n")
    else:
        (artifact_dir / "artifact-policy.txt").write_text("structured artifacts only; raw logs and xcresults omitted for passing invocations\n")
    print(f"Staged CI artifacts in {artifact_dir} (category={category})")


def cleanup(root: Path, keep: bool) -> None:
    if keep:
        print(f"Keeping diagnostic artifacts in {root} (--keep)")
        return
    removed = [0]
    for manifest_path in root.glob("*-invocation.json"):
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if manifest.get("status") != "passed" or manifest.get("exit_code") != 0:
            continue
        result_value = manifest.get("result_bundle")
        result = Path(result_value).expanduser().resolve() if isinstance(result_value, str) else None
        if result is not None:
            try:
                result.relative_to(root)
            except ValueError:
                result = None
        if result is not None:
            remove(result, removed)
            stem = result.name.removesuffix(".xcresult")
            remove(root / "raw" / f"{stem}.log", removed)
            remove(root / f"{stem}-diagnostics.attachments", removed)
        report_value = manifest.get("diagnostics_json")
        report = Path(report_value).expanduser().resolve() if isinstance(report_value, str) and report_value else None
        if report is not None:
            try:
                report.relative_to(root)
            except ValueError:
                report = None
        if report is not None:
            stem = report.name.removesuffix(".json")
            remove(report, removed)
            remove(report.with_suffix(".md"), removed)
            remove(report.with_suffix(".annotations"), removed)
            remove(report.with_name(f"{stem}.attachments"), removed)
        remove(manifest_path, removed)
    if not list(root.glob("*-invocation.json")):
        remove(root / "ci-diagnostics.json", removed)
        remove(root / "timing-log.jsonl", removed)
        remove(root / "raw", removed)
    print(f"Cleaned {removed[0]} successful diagnostic artifact(s) from {root}")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        raise SystemExit("Usage: diagnostic_maintenance.py <reset|stage|cleanup> RESULTS_DIR [ARTIFACT_DIR] [--keep]")
    mode = argv[0]
    root = require_results_dir(argv[1])
    if mode == "reset":
        reset(root)
    elif mode == "stage":
        if len(argv) < 3 or not argv[2]:
            raise SystemExit("stage requires an artifact directory")
        stage(root, Path(argv[2]).resolve())
    elif mode == "cleanup":
        cleanup(root, "--keep" in argv[2:])
    else:
        raise SystemExit(f"unknown maintenance mode: {mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
