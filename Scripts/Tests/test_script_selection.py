#!/usr/bin/env python3

"""Coverage for Scripts/script_test_selection.py regression routing.

Every Scripts/ leaf must either route to a narrow regression family or carry
an explicit reason in INTENTIONALLY_UNMAPPED; unmapped leaves silently fall
back to the full suite, which masks routing gaps.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

from script_test_support import ROOT

sys.path.insert(0, str(ROOT / "Scripts"))
from script_test_selection import FAMILIES, INTENTIONALLY_UNMAPPED, select_tests


def script_leaves() -> set[str]:
    leaves: set[str] = set()
    scripts = ROOT / "Scripts"
    for path in sorted(scripts.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith("Scripts/Tests/"):
            continue
        if path.suffix in {".md", ".pyc"} or path.name == "__pycache__" or ".DerivedData" in path.parts:
            continue
        if path.name.startswith("."):
            continue
        leaves.add(relative)
    return leaves


class ScriptSelectionTests(unittest.TestCase):
    def test_every_leaf_is_routed_or_intentionally_unmapped(self) -> None:
        routed = {owner for owners, _ in FAMILIES for owner in owners}
        unaccounted = script_leaves() - routed - set(INTENTIONALLY_UNMAPPED)
        self.assertEqual(unaccounted, set())

    def test_routing_references_exist(self) -> None:
        available = {
            path.relative_to(ROOT).as_posix() for path in (ROOT / "Scripts/Tests").iterdir()
        }
        for owners, modules in FAMILIES:
            for owner in owners:
                self.assertTrue((ROOT / owner).exists(), f"routed leaf is missing: {owner}")
            for module in modules:
                module_path = (
                    f"Scripts/Tests/{module}" if module.endswith(".sh") else f"Scripts/Tests/{module}.py"
                )
                self.assertIn(module_path, available, f"selected module is missing: {module}")
        for leaf in INTENTIONALLY_UNMAPPED:
            self.assertTrue((ROOT / leaf).exists(), f"unmapped leaf is missing: {leaf}")

    def test_selection_behavior(self) -> None:
        available = select_tests([])
        self.assertIn("Scripts/Tests/test_documentation.py", available)
        # Unknown/shared inputs run everything (fail-safe direction).
        self.assertEqual(select_tests(["Scripts/lib/does-not-exist.sh"]), available)
        self.assertEqual(select_tests(["Scripts/new-leaf.sh"]), available)
        # Mapped leaves narrow.
        narrowed = select_tests(["Scripts/check-links.py"])
        self.assertIn("Scripts/Tests/test_documentation.py", narrowed)
        self.assertLess(len(narrowed), len(available))
        # The selector itself runs just this module.
        self.assertEqual(
            select_tests(["Scripts/script_test_selection.py"]),
            ["Scripts/Tests/test_script_selection.py"],
        )
        # Docs are checked by their own gate, not the script suites.
        self.assertEqual(select_tests(["Scripts/Reference.md"]), [])


if __name__ == "__main__":
    unittest.main()
