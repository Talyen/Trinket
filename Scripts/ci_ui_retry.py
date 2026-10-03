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


def failed_cases(manifest: dict, report: dict, evidence: dict, targets: list[str]) -> list[str]:
    if (manifest.get("status") != "failed" or manifest.get("action") not in {"test", "test-without-building"}
            or not manifest.get("result_bundle_complete") or report.get("classification") != "simulator-infrastructure"):
        return []
    tests = evidence.get("tests", [])
    if not tests or any(test.get("result") not in {"Passed", "Failed"} for test in tests):
        return []
    names = [identifier(test["id"]) for test in tests]
    if (len(set(names)) != len(names) or set(names) != set(evidence.get("expected_tests", []))
            or any(not re.fullmatch(r"\w+/\w+", name) for name in names)):
        return []
    if any(not any(name == identifier(target) or name.startswith(identifier(target) + "/")
                   or target == "TrinketUITests" for name in names) for target in targets):
        return []
    failed = {identifier(test["id"]) for test in tests if test["result"] == "Failed"}
    summary = evidence.get("summary", {})
    if (not failed or summary.get("failed") != len(failed)
            or summary.get("passed") != len(tests) - len(failed) or summary.get("skipped") != 0):
        return []
    issues = report.get("issues", [])
    if not issues or any(issue.get("kind") != "simulator-infrastructure" for issue in issues):
        return []
    # Every failing case must have specific launch evidence; runner-only failure
    # evidence, unreadable/partial exports, and mixed assertion failures fail closed.
    issue_tests = {identifier(issue.get("test", "")) for issue in issues}
    if issue_tests != failed:
        return []
    return sorted(failed)


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
        retry_cases = recovery["retry_evidence"]["tests"]
        retry_names = {identifier(test["id"]) for test in retry_cases}
        return bool(failed) and (
            Path(manifest["result_bundle"], "Info.plist").is_file()
            and bool(manifest.get("session_id"))
            and retry.get("status") == "passed" and retry.get("exit_code") == 0
            and retry.get("session_id") == manifest.get("session_id")
            and retry.get("action") == "test-without-building"
            and retry.get("result_bundle_complete") is True
            and Path(retry["result_bundle"], "Info.plist").is_file()
            and retry_names == set(failed) and len(retry_cases) == len(failed)
            and all(test.get("result") == "Passed" for test in retry_cases)
            and recovery["retry_evidence"]["summary"]["failed"] == 0
            and recovery["retry_evidence"]["summary"]["passed"] == len(failed)
            and recovery["retry_evidence"]["summary"]["skipped"] == 0
        )
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False


def new_manifest(results: Path, before: set[Path], session: str, mode: str) -> Path | None:
    candidates = []
    for path in set(results.glob("*-invocation.json")) - before:
        payload = read(path)
        if payload.get("session_id") == session and payload.get("label") == mode:
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
