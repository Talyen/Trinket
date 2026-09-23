#!/usr/bin/env python3

"""Coverage for Scripts/script_test_selection.py regression routing.

Every Scripts/ leaf must either route to a narrow regression family or carry
an explicit reason in INTENTIONALLY_UNMAPPED; unmapped leaves silently fall
back to the full suite, which masks routing gaps.
"""

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/script_test_selection.py',
)


import sys
import tempfile
import unittest
from fnmatch import fnmatchcase
from pathlib import Path

from script_test_support import ROOT

sys.path.insert(0, str(ROOT / "Scripts"))
from script_test_selection import regression_families, INTENTIONALLY_UNMAPPED, select_tests


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
    def test_every_python_regression_declares_inputs(self) -> None:
        registered = {module for _, modules in regression_families()
                      for module in modules if not module.endswith(".sh")}
        available = {path.stem for path in (ROOT / "Scripts/Tests").glob("test*.py")}
        self.assertEqual(registered, available)

    def test_every_leaf_is_routed_or_intentionally_unmapped(self) -> None:
        patterns = {owner for owners, _ in regression_families() for owner in owners}
        unaccounted = {leaf for leaf in script_leaves() if leaf not in INTENTIONALLY_UNMAPPED
                       and not any(fnmatchcase(leaf, pattern) for pattern in patterns)}
        self.assertEqual(unaccounted, set())

    def test_routing_references_exist(self) -> None:
        available = {
            path.relative_to(ROOT).as_posix() for path in (ROOT / "Scripts/Tests").iterdir()
        }
        for owners, modules in regression_families():
            for owner in owners:
                self.assertTrue(list(ROOT.glob(owner)), f"routed leaf is missing: {owner}")
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

    def test_shared_regressions_follow_their_direct_inputs(self) -> None:
        for path in ("Scripts/build-inputs.env", "Scripts/config/diagnostic-limits.env"):
            with self.subTest(path=path):
                self.assertIn("Scripts/Tests/test_internal_cli.py", select_tests([path]))

    def test_product_paths_do_not_expand_script_regressions(self) -> None:
        selected = select_tests(["Scripts/check-links.py"])
        product_paths = (
            "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift",
            "Trinket/App/TrinketApp.swift",
            "TrinketUITests/Battle/BattleUITests.swift",
            "ContentManifest/abilities.tsv", "ArtManifest/art.tsv",
            "CinematicManifest/cinematics.tsv", "MusicManifest/music.tsv",
            "SoundManifest/sounds.tsv", "Raw Assets/Art/card.png",
            "StoreKit/Trinket.storekit", "Performance/scenarios.json",
        )
        for path in product_paths:
            with self.subTest(path=path):
                self.assertEqual(select_tests(["Scripts/check-links.py", path]), selected)
                self.assertEqual(select_tests([path]), [])
        self.assertEqual(select_tests(["Scripts/check-links.py", ".github/workflows/tests.yml"]),
                         select_tests([]))
        self.assertEqual(select_tests(["Scripts/check-links.py", "project.yml"]), select_tests([]))
        self.assertEqual(select_tests(["Gemfile"]), ["Scripts/Tests/test_testflight.py"])
        self.assertEqual(select_tests(["Gemfile.lock"]), ["Scripts/Tests/test_testflight.py"])

    def test_script_runner_accepts_absolute_repository_paths(self) -> None:
        import subprocess

        relative = "Scripts/Tests/test_internal_cli.py"
        outputs = []
        for path in (relative, str(ROOT / relative)):
            result = subprocess.run(
                ["bash", "Scripts/test-scripts.sh", "--fast", "--paths", path],
                cwd=ROOT, capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Script scope: 1 Python and 0 shell suites.", result.stdout)
            self.assertIn("Script syntax passed", result.stdout)
            outputs.append([line for line in result.stdout.splitlines()
                            if line.startswith(("Script scope:", "=== ", "test_internal_cli passed"))])
        self.assertEqual(outputs[0], outputs[1])

        for path in (str(ROOT / "Scripts"), str(ROOT.parent / "outside.py")):
            result = subprocess.run(
                ["bash", "Scripts/test-scripts.sh", "--fast", "--paths", path],
                cwd=ROOT, capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("--paths", result.stderr)

    def test_literal_metadata_is_not_executed_and_globs_union_consumers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / "Scripts/Tests"
            tests.mkdir(parents=True)
            (tests / "test_one.py").write_text(
                "SCRIPT_INPUTS = ('Scripts/domain/*.json', 'Packages/Game/Sources/Owned.swift')\n"
                "raise RuntimeError('must not execute')\n")
            (tests / "test_two.py").write_text("SCRIPT_INPUTS = ['Scripts/domain/known.json']\n")
            all_tests = select_tests([], root)
            self.assertEqual(select_tests(['Scripts/domain/known.json'], root), all_tests)
            self.assertEqual(select_tests(['Scripts/domain/new.json'], root), ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Packages/Game/Sources/Owned.swift'], root),
                             ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Scripts/domain/new.json', 'Packages/Game/Sources/Other.swift'], root),
                             ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Scripts/unmapped.py'], root), all_tests)
            self.assertEqual(select_tests(['Scripts/Tests/test_two.py'], root), ['Scripts/Tests/test_two.py'])
            for source in ("SCRIPT_INPUTS = get_paths()", "SCRIPT_INPUTS = ('../outside.py',)",
                           "SCRIPT_INPUTS = 'Scripts/one.py'", "SCRIPT_INPUTS = ()\nSCRIPT_INPUTS = ()"):
                (tests / "test_one.py").write_text(source)
                with self.assertRaisesRegex(ValueError, 'invalid test ownership'):
                    select_tests(['Scripts/domain/known.json'], root)


if __name__ == "__main__":
    unittest.main()
