#!/usr/bin/env python3

"""Coverage for Scripts/script_test_selection.py regression routing.

Every Scripts/ leaf must either route to a narrow regression family or carry
an explicit reason in INTENTIONALLY_UNMAPPED; unmapped leaves silently fall
back to the full suite, which masks routing gaps.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
import unittest
from fnmatch import fnmatchcase
from pathlib import Path

from script_test_support import ROOT, run_captured, write_executable

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
    def test_every_python_regression_has_an_owner(self) -> None:
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
            "MusicManifest/music.tsv",
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
        with tempfile.TemporaryDirectory() as directory:
            root = self.runner_fixture(Path(directory))
            scripts = root / 'Scripts'
            # Exercise the real normalization, selector, syntax pass and worker;
            # the leaf suite's behavior already has its own independent owner.
            for name in ('internal/change_routing.py', 'internal/agent_status.py', 'internal/ui_registration.py'):
                shutil.copy2(ROOT / 'Scripts' / name, scripts / name)
            (scripts / 'config/script-regressions.tsv').write_text('')
            relative = 'Scripts/Tests/test_probe.py'
            probe = root / relative
            probe.write_text('import unittest\nfrom pathlib import Path\n'
                             'class Probe(unittest.TestCase):\n'
                             '    def test_selected(self): Path("executed").touch()\n')
            marker = root / 'executed'
            outputs = []
            for path in (relative, str(probe)):
                result = run_captured(['bash', 'Scripts/test-scripts.sh', '--fast', '--paths', path], cwd=root, expected=0)
                self.assertTrue(marker.exists(), 'selected worker must actually execute')
                marker.unlink()
                self.assertIn('Script scope: 1 Python and 0 shell suites.', result.stdout)
                self.assertIn('Script syntax passed', result.stdout)
                outputs.append([line for line in result.stdout.splitlines()
                                if line.startswith(('Script scope:', '=== '))])
            self.assertEqual(outputs[0], outputs[1])

            for path in (str(scripts), str(root.parent / 'outside.py')):
                result = run_captured(['bash', 'Scripts/test-scripts.sh', '--fast', '--paths', path], cwd=root)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('--paths', result.stderr)
                self.assertFalse(marker.exists(), 'invalid scope must fail before executing workers')

    def runner_fixture(self, root: Path) -> Path:
        scripts = root / 'Scripts'
        (scripts / 'Tests').mkdir(parents=True)
        for name in ('test-scripts.sh', 'lib/args.sh', 'script_diagnostics.py',
                     'internal/diagnostics/diagnostic_limits.py', 'config/diagnostic-limits.env',
                     'cleanup-outputs.py', 'internal/output_retention.py', 'internal/cli.py',
                     'lib/output-retention.sh', 'lib/lock.sh', 'script_test_selection.py',
                     'script_test_execution.py'):
            (scripts / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / 'Scripts' / name, scripts / name)
        write_executable(scripts / 'check-build-cache-paths.sh', '#!/bin/sh\nexit 0\n')
        (scripts / 'check-docs.py').write_text('raise RuntimeError("docs must be skipped")\n')
        return root

    def test_runner_compiles_without_execution_and_preserves_worker_failures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.runner_fixture(Path(directory))
            scripts = root / "Scripts"
            tests = scripts / "Tests"
            (scripts / "script_test_selection.py").write_text(
                'print("Scripts/Tests/test_first.py\\nScripts/Tests/test_last.py\\nScripts/Tests/test-peer.sh")\n')
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
            environment = {**os.environ, "TRINKET_SCRIPT_TEST_JOBS": "2", "TRINKET_KEEP_REPORTS": "0",
                           "RESULTS_DIR": str(root / "logs")}

            def run():
                return run_captured(["/bin/bash", "Scripts/test-scripts.sh", "--skip-docs"], cwd=root, env=environment)

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

    def test_python_worker_rejects_empty_skipped_and_unimportable_suites(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            (scripts / 'Tests').mkdir(parents=True)
            shutil.copy2(ROOT / 'Scripts/script_test_execution.py', scripts)
            probe = scripts / 'Tests/test_probe.py'
            for source, status, message in (
                ('', 1, 'zero successful tests'),
                ('import unittest\n@unittest.skip("unavailable")\nclass Probe(unittest.TestCase):\n'
                 '    def test_skipped(self): self.fail("must not execute")\n', 1, 'zero successful tests'),
                ('raise ImportError("broken fixture")\n', 1, 'broken fixture'),
                ('import unittest\nclass Probe(unittest.TestCase):\n'
                 '    def test_partial(self):\n'
                 '        for available in (False, True):\n'
                 '            with self.subTest(available=available):\n'
                 '                if not available: self.skipTest("unavailable")\n'
                 '                self.assertTrue(available)\n', 0, 'OK'),
            ):
                with self.subTest(source=source):
                    probe.write_text(source)
                    # Keep rapid rewrites from reusing timestamp-based bytecode.
                    shutil.rmtree(probe.parent / '__pycache__', ignore_errors=True)
                    # Failure propagation and selection already run through the
                    # real shell runner above; these are Python worker outcomes.
                    result = run_captured([sys.executable, str(scripts / 'script_test_execution.py'),
                                           'test_probe'], cwd=root)
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertIn(message, result.stdout + result.stderr)

    def test_registry_is_data_and_globs_union_consumers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / "Scripts/Tests"
            tests.mkdir(parents=True)
            registry = root / "Scripts/config/script-regressions.tsv"
            registry.parent.mkdir()
            (tests / "test_one.py").write_text("raise RuntimeError('must not execute')\n")
            (tests / "test_two.py").touch()
            registry.write_text(
                "# input\tsuites\n"
                "Scripts/domain/*.json\ttest_one.py\n"
                "Scripts/domain/known.json\ttest_two.py\n"
                "Scripts/other.py\ttest_two.py\n"
                "Packages/Game/Sources/Owned.swift\ttest_one.py\n")
            all_tests = select_tests([], root)
            self.assertEqual(select_tests(['Scripts/domain/known.json'], root), all_tests)
            self.assertEqual(select_tests(['Scripts/domain/new.json'], root), ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Scripts/domain/new.json', 'Scripts/other.py'], root), all_tests)
            self.assertEqual(select_tests(['Packages/Game/Sources/Owned.swift'], root),
                             ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Scripts/domain/new.json', 'Packages/Game/Sources/Other.swift'], root),
                             ['Scripts/Tests/test_one.py'])
            self.assertEqual(select_tests(['Scripts/unmapped.py'], root), all_tests)
            self.assertEqual(select_tests(['Scripts/Tests/test_two.py'], root), ['Scripts/Tests/test_two.py'])
            self.assertEqual(select_tests(['Scripts/config/script-regressions.tsv'], root), all_tests)
            for row in ("../outside.py\ttest_one.py", "/absolute.py\ttest_one.py",
                        "Scripts/Tests\ttest_one.py", "Scripts/one.py", "Scripts/one.py\t",
                        "Scripts/one.py\t../test_one.py", "Scripts/one.py\tnot-a-suite.py",
                        "Scripts/one.py\ttest_one.py,test_one.py", "Scripts/one.py\t test_one.py",
                        "Scripts/one.py\ttest_one.py\textra",
                        "Scripts/one.py\ttest_one.py\nScripts/one.py\ttest_two.py"):
                with self.subTest(row=row):
                    registry.write_text(row + "\n")
                    with self.assertRaisesRegex(ValueError, 'invalid test ownership'):
                        select_tests(['Scripts/domain/known.json'], root)
            registry.write_text("Scripts/one.py\ttest_missing.py\n")
            with self.assertRaisesRegex(ValueError, 'selected regression modules are missing'):
                select_tests(['Scripts/one.py'], root)
            registry.unlink()
            with self.assertRaisesRegex(ValueError, 'invalid test ownership'):
                select_tests(['Scripts/one.py'], root)

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
