#!/usr/bin/env python3
"""Check smoke/FullUI test-plan registry sync."""

from __future__ import annotations

import json
import re
import shlex
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def testplan_failures() -> list[str]:
    failures: list[str] = []
    plan = json.loads((ROOT / "Smoke.xctestplan").read_text(encoding="utf-8"))
    selected = {
        test
        for target in plan["testTargets"]
        for test in target.get("selectedTests", [])
    }
    registry = set()
    for line in (ROOT / "Scripts" / "config" / "smoke-classes.txt").read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped or not stripped.split("=", 1)[1].strip():
            failures.append(f"Scripts/config/smoke-classes.txt: malformed line (expected KEY=Class): {stripped}")
            continue
        registry.add(stripped.split("=", 1)[1])
    if selected != registry:
        failures.append(
            "Smoke.xctestplan selectedTests must match Scripts/config/smoke-classes.txt "
            f"(plan={sorted(selected)}, registry={sorted(registry)})"
        )
    workflow = (ROOT / ".github/workflows/tests.yml").read_text(encoding="utf-8")
    for plan_name, job, smoke in [("Smoke", "smoke", True), ("FullUI", "exhaustive-ui", False)]:
        plan = json.loads((ROOT / f"{plan_name}.xctestplan").read_text(encoding="utf-8"))
        selections = [test for target in plan["testTargets"] for test in target.get("selectedTests", [])]
        declared: set[str] = set()
        for path in sorted((ROOT / "TrinketUITests").rglob("*.swift")):
            parts = path.relative_to(ROOT).parts
            if any(part in {"Performance", "Support"} for part in parts) or ("Smoke" in parts) != smoke:
                continue
            declared.update(re.findall(
                r"(?:final\s+)?class\s+(\w+)\s*:\s*(?:SeededSmokeUITestCase|TrinketUITestCase)",
                path.read_text(encoding="utf-8"),
            ))
        selected = set(selections)
        if selected != declared:
            failures.append(f"{plan_name}.xctestplan class mismatch: "
                            f"missing={sorted(declared - selected)}, undeclared={sorted(selected - declared)}")
        duplicates = sorted(name for name, count in Counter(selections).items() if count > 1)
        if duplicates:
            failures.append(f"{plan_name}.xctestplan duplicate classes: {duplicates}")

        # Read only literal target rows in this job's checked-in matrix layout.
        section = re.search(rf"^  {re.escape(job)}:\n(.*?)(?=^  [\w-]+:|\Z)", workflow, re.M | re.S)
        matrix = re.search(r"^      matrix:\n(.*?)(?=^    \S|\Z)", section[1], re.M | re.S) if section else None
        targets: list[str] = []
        if matrix:
            for value in re.findall(r"^            target: (.+)$", matrix[1], re.M):
                targets.extend(shlex.split(value, comments=True))
        if set(targets) != selected:
            failures.append(f".github/workflows/tests.yml {job} matrix mismatch: "
                            f"missing={sorted(selected - set(targets))}, extra={sorted(set(targets) - selected)}")
        duplicates = sorted(name for name, count in Counter(targets).items() if count > 1)
        if duplicates:
            failures.append(f".github/workflows/tests.yml {job} duplicate classes: {duplicates}")
    return failures


def main() -> int:
    for argument in sys.argv[1:]:
        print(f"Usage: {Path(sys.argv[0]).name}", file=sys.stderr)
        return 2
    failures = testplan_failures()
    if failures:
        print("Test plan sync checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print("Test plan sync passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
