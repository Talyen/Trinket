#!/usr/bin/env python3
"""Retry only fully identified infrastructure-failed UI cases once, on the same runner."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

from internal.cli import load_sibling

parse_xcresult = load_sibling("test_timing", "test-timing.py").parse_xcresult


def read(path: str | Path) -> dict:
    return json.loads(Path(path).read_text())


def identifier(value: str) -> str:
    return value.removeprefix("TrinketUITests/").removesuffix("()")


def expected_cases(targets: list[str], root: Path = Path("TrinketUITests")) -> list[str]:
    # Routine XCTest classes declare named methods directly. Unsupported dynamic,
    # inherited, or conditional discovery cannot authorize a partial-suite pass.
    declared: dict[str, set[str]] = {}
    for path in root.rglob("*.swift"):
        if any(part in {"Support", "Performance"} for part in path.parts):
            continue
        text = path.read_text()
        blocks = list(re.finditer(r"^(?:final )?(?:class|extension) (\w+)[^\n]*\{", text, re.M))
        for index, block in enumerate(blocks):
            finish = blocks[index + 1].start() if index + 1 < len(blocks) else len(text)
            methods = re.findall(r"^    func (test\w+)\(", text[block.end():finish], re.M)
            declared.setdefault(block[1], set()).update(f"{block[1]}/{method}" for method in methods)
    selected = set()
    for target in targets:
        name = identifier(target)
        suite = name.split("/", 1)[0]
        cases = declared.get(suite, set())
        matching = {case for case in cases if name == suite or name == case}
        if not matching:
            return []
        selected.update(matching)
    return sorted(selected)


def test_results(evidence: dict) -> dict[str, str] | None:
    """Accept only complete, unique case results with matching integer totals."""
    tests = evidence.get("tests")
    if not isinstance(tests, list) or not tests:
        return None
    results = {}
    for test in tests:
        if not isinstance(test, dict) or not isinstance(test.get("id"), str):
            return None
        name = identifier(test["id"])
        if (not re.fullmatch(r"\w+/\w+", name) or name in results
                or test.get("result") not in ("Passed", "Failed")):
            return None
        results[name] = test["result"]
    summary = evidence.get("summary")
    counts = {"passed": sum(value == "Passed" for value in results.values()),
              "failed": sum(value == "Failed" for value in results.values()), "skipped": 0}
    if not isinstance(summary, dict) or any(type(summary.get(key)) is not int or summary[key] != count
                                           for key, count in counts.items()):
        return None
    return results


def failed_cases(manifest: dict, report: dict, evidence: dict, targets: list[str]) -> list[str]:
    if (manifest.get("status") != "failed" or manifest.get("action") not in {"test", "test-without-building"}
            or manifest.get("result_bundle_complete") is not True or report.get("classification") != "simulator-infrastructure"):
        return []
    results = test_results(evidence)
    expected = evidence.get("expected_tests")
    if (not results or not isinstance(expected, list) or not all(isinstance(name, str) for name in expected)
            or set(results) != set(expected) or len(results) != len(expected)
            or not targets or not all(isinstance(target, str) for target in targets)):
        return []
    target_names = {identifier(target) for target in targets}
    if any(not any(name == target or name.startswith(target + "/") or target == "TrinketUITests"
                   for name in results) for target in target_names):
        return []
    failed = {name for name, result in results.items() if result == "Failed"}
    issues = report.get("issues")
    if (not failed or not isinstance(issues, list) or not issues
            or any(not isinstance(issue, dict) or issue.get("kind") != "simulator-infrastructure"
                   or not isinstance(issue.get("test"), str) for issue in issues)):
        return []
    # Each failed case needs launch evidence; mixed assertions fail closed.
    return sorted(failed) if {identifier(issue["test"]) for issue in issues} == failed else []


def recovery_valid(manifest: dict, report: dict) -> bool:
    """Validate stored execution proof without another expensive xcresult export."""
    recovery = manifest.get("infrastructure_recovery")
    if not isinstance(recovery, dict):
        return False
    try:
        retry = read(recovery["retry_manifest"])
        original = recovery["original_evidence"]
        targets = recovery["targets"]
        failed = failed_cases(manifest, report, original, targets)
        retry_results = test_results(recovery["retry_evidence"])
        return bool(failed) and (
            Path(manifest["result_bundle"], "Info.plist").is_file()
            and bool(manifest.get("session_id"))
            and retry.get("status") == "passed" and type(retry.get("exit_code")) is int and retry["exit_code"] == 0
            and retry.get("session_id") == manifest.get("session_id")
            and retry.get("action") == "test-without-building"
            and retry.get("result_bundle_complete") is True
            and Path(retry["result_bundle"], "Info.plist").is_file()
            and retry_results is not None and set(retry_results) == set(failed)
            and all(result == "Passed" for result in retry_results.values())
        )
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False


def new_manifest(results: Path, before: set[Path], session: str, mode: str) -> Path | None:
    candidates = []
    for path in set(results.glob("*-invocation.json")) - before:
        try:
            payload = read(path)
        except (OSError, ValueError):
            continue
        if isinstance(payload, dict) and payload.get("session_id") == session and payload.get("label") == mode:
            candidates.append(path)
    return candidates[0] if len(candidates) == 1 else None


def run(command: list[str]) -> int:
    if len(command) < 2 or command[0] != "./Scripts/test.sh" or command[1] not in {"ui", "smoke"}:
        return subprocess.call(command)
    mode = command[1]
    targets = [value for value in command[2:] if not value.startswith("--")]
    # The CI workflow always supplies explicit registry filters. Do not invent
    # missing-suite execution proof for unfiltered or compilation invocations.
    if "--no-build" not in command or not targets:
        return subprocess.call(command)
    results = Path(os.environ.get("RESULTS_DIR", ".DerivedData/TestResults")).resolve()
    session = "ui-retry-" + uuid.uuid4().hex
    env = {**os.environ, "TRINKET_DIAGNOSTICS_SESSION_ID": session,
           "TRINKET_TARGETED_UI_RETRY": "1", "TRINKET_CLEANUP_TEST_ARTIFACTS": "0"}
    before = set(results.glob("*-invocation.json"))
    status = subprocess.call(command, env=env)
    if status == 0:
        return 0
    try:
        original_path = new_manifest(results, before, session, mode)
        if original_path is None:
            return status
        original = read(original_path)
        report = read(original["diagnostics_json"])
        if report.get("classification") != "simulator-infrastructure" or not original.get("result_bundle_complete"):
            return status
        evidence = parse_xcresult(Path(original["result_bundle"]))
        evidence["expected_tests"] = expected_cases(targets)
        cases = failed_cases(original, report, evidence, targets)
        if not cases:
            return status
        print("::warning::Retrying infrastructure-failed UI cases once: " + ", ".join(cases), flush=True)
        # test.sh owns managed simulator leases/guest cleanup. Each UI test seeds
        # its own initial state, so successfully completed cases need not rerun.
        before = set(results.glob("*-invocation.json"))
        retry_status = subprocess.call(["./Scripts/test.sh", mode, "--no-build", *cases], env={**env, "TRINKET_REPREP_UI_SIMULATOR": "1"})
        if retry_status != 0:
            return retry_status
        retry_path = new_manifest(results, before, session, mode)
        if retry_path is None:
            return status
        retry = read(retry_path)
        original["infrastructure_recovery"] = {
            "retry_manifest": str(retry_path), "targets": targets,
            "original_evidence": evidence,
            "retry_evidence": parse_xcresult(Path(retry["result_bundle"])),
        }
        if not recovery_valid(original, report):
            return status
        temporary = original_path.with_suffix(".recovery.tmp")
        temporary.write_text(json.dumps(original) + "\n")
        temporary.replace(original_path)
        print("UI coverage passed across the original invocation and the targeted infrastructure retry.", flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, SystemExit) as error:
        print(f"Cannot prove targeted UI recovery; retaining failure: {error}", file=sys.stderr)
        return status


if __name__ == "__main__":
    raise SystemExit(run(sys.argv[1:]))
