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
    payload = json.loads(Path(path).read_text())
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return payload


def identifier(value: str) -> str:
    return value.removeprefix("TrinketUITests/").removesuffix("()")


def expected_cases(targets: list[str], root: Path = Path("TrinketUITests")) -> list[str]:
    # A recovery can only pass when every statically discoverable case is accounted for.
    scanner = load_sibling('retry_swift_scanner', 'check-testplan-sync.py')
    methods: dict[str, set[str]] = {}
    parents: dict[str, set[str]] = {}
    conditional: set[str] = set()
    for path in root.rglob("*.swift"):
        if "Performance" in path.relative_to(root).parts:
            continue
        try:
            source = scanner.swift_code(path.read_text())
            for name, parent in scanner.swift_classes(source):
                bases = parents.setdefault(name, set())
                if parent:
                    bases.add(parent)
        except (OSError, ValueError):
            return []
        depth = 0
        depths = []
        for character in source:
            depths.append(depth)
            depth += (character == '{') - (character == '}')
            if depth < 0:
                return []
        if depth:
            return []
        conditional_file = any(depths[match.start()] == 0 for match in
                               re.finditer(r'(?m)^\s*#(?:if|elseif|else|endif)\b', source))
        for block in re.finditer(r'\b(?:class|extension)\s+(`?\w+`?)', source):
            if depths[block.start()] != 0:
                continue
            opening = source.find('{', block.end())
            if opening < 0:
                return []
            finish = next((index for index in range(opening + 1, len(source))
                           if source[index] == '}' and depths[index] == 1), None)
            if finish is None:
                return []
            name = block[1].strip('`')
            methods.setdefault(name, set())
            body = source[opening + 1:finish]
            if (conditional_file or re.search(r'(?m)^\s*#(?:if|elseif|else|endif)\b', body)
                    or re.search(r'@(?:objc|Test|Suite)\b', body)):
                conditional.add(name)
            for match in re.finditer(r'\bfunc\s+(`?test\w+`?)\s*\(\s*\)', body):
                if depths[opening + 1 + match.start()] == 1:
                    methods[name].add(match[1].strip('`'))

    def cases_for(name: str, seen: set[str]) -> set[str] | None:
        if name == 'XCTestCase':
            return None if name in conditional else set(methods.get(name, ()))
        if name in seen or name in conditional or name not in parents:
            return None
        cases = set(methods.get(name, ()))
        for parent in parents[name]:
            inherited = cases_for(parent, seen | {name})
            if inherited is None:
                return None
            cases.update(inherited)
        return cases

    selected = set()
    for target in targets:
        name = identifier(target)
        suite = name.split("/", 1)[0]
        discovered = cases_for(suite, set())
        if discovered is None:
            return []
        cases = {f'{suite}/{method}' for method in discovered}
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
        arguments = test.get("arguments", [])
        if (not re.fullmatch(r"\w+/\w+", name) or name in results
                or test.get("result") not in ("Passed", "Failed")
                or not isinstance(arguments, list)
                or any(result not in ("Passed", "Failed") for result in arguments)
                or (arguments and ("Failed" in arguments) != (test["result"] == "Failed"))):
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
                   for target in target_names) for name in results):
        return []
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
            and Path(manifest["result_bundle"]).resolve() != Path(retry["result_bundle"]).resolve()
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
    session = os.environ.get("TRINKET_DIAGNOSTICS_SESSION_ID") or "ui-retry-" + uuid.uuid4().hex
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
        evidence = parse_xcresult(Path(original["result_bundle"]), original)
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
            "retry_evidence": parse_xcresult(Path(retry["result_bundle"]), retry),
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
