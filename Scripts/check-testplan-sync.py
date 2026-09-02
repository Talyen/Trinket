#!/usr/bin/env python3
"""Check smoke/FullUI test-plan registry sync."""

from __future__ import annotations

import json
import re
import sys
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
    ui_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "TrinketUITests").rglob("*.swift"))
    )
    for test_class in sorted(selected):
        if not re.search(rf"\b(?:final\s+)?class\s+{re.escape(test_class)}\b", ui_source):
            failures.append(f"Smoke.xctestplan: selected class {test_class} is not declared")

    # FullUI coverage guard: every UI test class outside Smoke/ and Performance/
    # must be selected in FullUI.xctestplan, and every FullUI class must appear
    # in the exhaustive-ui CI matrix. Plans use `automaticallyIncludesTests:
    # false`, so a new class is silently skipped everywhere without this check.
    fullui_plan = json.loads((ROOT / "FullUI.xctestplan").read_text(encoding="utf-8"))
    fullui_selected = {
        test
        for target in fullui_plan["testTargets"]
        for test in target.get("selectedTests", [])
    }
    routable_classes: set[str] = set()
    for path in sorted((ROOT / "TrinketUITests").rglob("*.swift")):
        parts = path.relative_to(ROOT).parts
        if any(part in {"Smoke", "Performance", "Support"} for part in parts):
            continue
        routable_classes.update(
            name
            for name in re.findall(
                r"(?:final\s+)?class\s+(\w+)\s*:\s*(?:SeededSmokeUITestCase|TrinketUITestCase)",
                path.read_text(encoding="utf-8"),
            )
            if name.endswith("Tests")
        )
    missing_fullui = sorted(routable_classes - fullui_selected)
    if missing_fullui:
        failures.append(
            "FullUI.xctestplan is missing UI test classes "
            f"{missing_fullui} (add them to the plan or move the files under Smoke/ or Performance/)"
        )
    ci_workflow_text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
    missing_ci = sorted(name for name in fullui_selected if name not in ci_workflow_text)
    if missing_ci:
        failures.append(
            f".github/workflows/tests.yml exhaustive-ui matrix is missing FullUI classes: {missing_ci}"
        )
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
