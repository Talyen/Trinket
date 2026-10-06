#!/usr/bin/env python3

"""Coverage for Scripts/script_test_selection.py regression routing.

Every Scripts/ leaf must either route to a narrow regression family or carry
an explicit reason in INTENTIONALLY_UNMAPPED; unmapped leaves silently fall
back to the full suite, which masks routing gaps.
"""

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/script_test_selection.py',
    'Scripts/test-scripts.sh',
)


import os
import shutil
import subprocess
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
                      for module in modules if module.endswith(".py")}
        available = {path.relative_to(ROOT).as_posix() for path in (ROOT / "Scripts/Tests").glob("test*.py")}
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
                self.assertIn(module, available, f"selected module is missing: {module}")
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
                            if line.startswith(("Script scope:", "=== "))])
        self.assertEqual(outputs[0], outputs[1])

        for path in (str(ROOT / "Scripts"), str(ROOT.parent / "outside.py")):
            result = subprocess.run(
                ["bash", "Scripts/test-scripts.sh", "--fast", "--paths", path],
                cwd=ROOT, capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("--paths", result.stderr)

    def test_runner_compiles_without_execution_and_preserves_worker_failures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            tests = scripts / "Tests"
            tests.mkdir(parents=True)
            (scripts / "lib").mkdir()
            for name in ("test-scripts.sh", "lib/args.sh", "script_diagnostics.py",
                         "internal/diagnostics/diagnostic_limits.py", "config/diagnostic-limits.env",
                         "cleanup-outputs.py", "internal/output_retention.py", "internal/cli.py",
                         "lib/output-retention.sh", "lib/lock.sh"):
                (scripts / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, scripts / name)
            (scripts / "script_test_selection.py").write_text(
                'print("Scripts/Tests/test_first.py\\nScripts/Tests/test_last.py\\nScripts/Tests/test-peer.sh")\n')
            (scripts / "check-build-cache-paths.sh").write_text('#!/bin/sh\nexit 0\n')
            (scripts / "check-build-cache-paths.sh").chmod(0o755)
            (scripts / "check-docs.py").write_text('raise RuntimeError("docs must be skipped")\n')
            # A syntactically valid file must never execute during compilation.
            (scripts / "syntax_probe.py").write_text('raise RuntimeError("syntax executed")\n')
            first = tests / "test_first.py"
            last = tests / "test_last.py"
            first.write_text('import unittest, time\nfrom pathlib import Path\n'
                             'class Probe(unittest.TestCase):\n'
                             '    def test_failure(self):\n'
                             '        deadline = time.monotonic() + 5\n'
                             '        while not Path("shell-worker").exists() and time.monotonic() < deadline: time.sleep(0.01)\n'
                             '        self.assertTrue(Path("shell-worker").exists(), "shell must overlap Python")\n'
                             '        self.fail("worker failure sentinel")\n')
            shell = tests / "test-peer.sh"
            shell.write_text('#!/bin/sh\ntouch shell-worker\necho shell failure sentinel\nexit 7\n')
            last.write_text('import unittest\nfrom pathlib import Path\n'
                            'class Probe(unittest.TestCase):\n'
                            '    def test_worker(self): Path("last-worker").touch()\n')
            environment = {**os.environ, "TRINKET_SCRIPT_TEST_JOBS": "2", "RESULTS_DIR": str(root / "logs")}

            def run():
                return subprocess.run(["/bin/bash", "Scripts/test-scripts.sh", "--skip-docs"],
                                      cwd=root, env=environment, capture_output=True, text=True)

            rejected = scripts / "broken.py"
            rejected.write_text('def broken(\n')
            result = run()
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("broken.py", result.stderr)
            self.assertFalse((root / "last-worker").exists())
            rejected.unlink()
            result = run()
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertTrue((root / "last-worker").exists(), "failure must not suppress other selected suites")
            self.assertIn("worker failure sentinel", result.stderr)
            self.assertIn("Script test logs retained:", result.stderr)
            shell_logs = list((root / "logs").glob("*/test-peer.sh.log"))
            self.assertEqual(len(shell_logs), 1)
            self.assertIn("shell failure sentinel", shell_logs[0].read_text())
            first.write_text('import unittest\nclass Probe(unittest.TestCase):\n'
                             '    def test_success(self): self.assertTrue(True)\n')
            result = run()
            self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
            self.assertIn("shell failure sentinel", result.stderr)
            shell.write_text('#!/bin/sh\ntouch shell-worker\n')
            shutil.rmtree(root / "logs")
            environment["TRINKET_SCRIPT_TEST_JOBS"] = "1"
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(list((root / "logs").iterdir()), [])

            selector = scripts / "script_test_selection.py"
            selector.write_text('print("Scripts/Tests/test_last.py")\n')
            (root / "last-worker").unlink()
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((root / "last-worker").exists(), "Python-only selection must execute")
            self.assertIn("test_last passed", result.stdout)
            last.write_text('import unittest\nclass Probe(unittest.TestCase):\n'
                            '    def test_failure(self): self.fail("Python-only failure sentinel")\n')
            result = run()
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("Python-only failure sentinel", result.stderr)

            selector.write_text('print("Scripts/Tests/test-peer.sh")\n')
            (root / "shell-worker").unlink()
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((root / "shell-worker").exists(), "shell-only selection must execute")
            shell.write_text('#!/bin/sh\necho shell-only failure sentinel\nexit 7\n')
            result = run()
            self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
            self.assertIn("shell-only failure sentinel", result.stderr)

            selector.write_text('print("")\n')
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("(no regressions selected)", result.stdout)
            self.assertIn("Script checks passed", result.stdout)

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

    def test_scope_validation_precedes_fallback_and_rejects_symlink_escapes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            (root / 'Scripts/Tests').mkdir(parents=True)
            outside = Path(directory) / 'outside.py'
            outside.touch()
            (root / 'alias.py').symlink_to(outside)
            for path in ('alias.py', '../outside.py', 'Scripts'):
                with self.subTest(path=path), self.assertRaises(ValueError):
                    select_tests(['unknown-input', path], root)


if __name__ == "__main__":
    unittest.main()
