#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-gate.sh',
    'Scripts/config/cheap-slices.txt',
    'Scripts/handoff.sh',
    'Scripts/verify.py',
    'Scripts/internal/change_routing.py',
    'Scripts/internal/ui_registration.py',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/gate.sh',
)

import re
import shlex
import shutil
import subprocess
import unittest
from unittest.mock import patch
import contextlib
import io

from script_test_support import ROOT, ScriptRegressionTestCase

import os
import tempfile
from pathlib import Path

class CIHandoffRoutingTests(ScriptRegressionTestCase):
    def test_gemfile_changes_select_script_regressions(self) -> None:
        for hosted in (False, True):
            for path in ("Gemfile", "Gemfile.lock"):
                with self.subTest(path=path, hosted=hosted):
                    result = subprocess.run(
                        [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", path],
                        cwd=ROOT, env=self.verification_environment(hosted=hosted),
                        capture_output=True, text=True, check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    flag = "" if hosted else " --fast"
                    self.assertIn(f"./Scripts/test-scripts.sh{flag} --paths {path}", result.stdout)

    def test_mixed_script_and_product_scope_keeps_narrow_regressions(self) -> None:
        script_only = subprocess.run(
            ["python3", "Scripts/script_test_selection.py", "--paths", "Scripts/check-links.py"],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(script_only.returncode, 0, script_only.stderr)
        for hosted in (False, True):
            with self.subTest(hosted=hosted):
                result = subprocess.run(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths",
                     "Scripts/check-links.py", "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift"],
                    cwd=ROOT, env=self.verification_environment(hosted=hosted),
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                command = next(line.strip() for line in result.stdout.splitlines()
                               if line.strip().startswith("./Scripts/test-scripts.sh "))
                arguments = shlex.split(command)
                self.assertEqual('--fast' in arguments, not hosted)
                paths = arguments[arguments.index('--paths') + 1:]
                selected = subprocess.run(
                    ["python3", "Scripts/script_test_selection.py", "--paths", *paths],
                    cwd=ROOT, capture_output=True, text=True, check=False,
                )
                self.assertEqual(selected.returncode, 0, selected.stderr)
                self.assertEqual(selected.stdout, script_only.stdout)

    def test_product_routes_preserve_package_and_smoke_owners(self) -> None:
        support = "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport"
        feature = "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features"
        cases = (
            (["Trinket/Features/Play/Mystery/MysteryChoiceCard.swift"], None, "SmokeShellTests"),
            (["Trinket/Features/Play/Modes/PlayModeHubView.swift"], None, "SmokeShellTests"),
            ([f"{support}/Shared/HomesteadResourceArtwork.swift"], "TrinketFeatureSupport", None),
            ([f"{support}/Accessibility/AccessibilityID.swift"], "TrinketFeatureSupport", "SmokeShellTests"),
            ([f"{support}/Artwork/PreparedArtwork.swift"], "TrinketFeatureSupport", "SmokeShellTests"),
            ([f"{feature}/Effects/CombatantCardDeathEffectVariants.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            ([f"{feature}/Battlefield/BattleCombatantPane.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            ([f"{feature}/Effects/CombatantCardDeathEffectVariants.swift",
              f"{feature}/Battlefield/BattleCombatantPane.swift"], "TrinketBattleFeature", "SmokeBattleTests"),
            (["Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattleRuntime.swift"], "TrinketFeatureSupport", None),
        )
        for paths, package, smoke in cases:
            with self.subTest(paths=paths):
                result = subprocess.run(
                    [str(ROOT / "Scripts/handoff.sh"), "--dry-run", *(["--smoke"] if smoke else []),
                     "--paths", *paths], cwd=ROOT, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                commands = [line.strip().removeprefix("SKIP_GENERATE=1 ") for line in result.stdout.splitlines()]
                if package:
                    self.assertEqual(commands.count(f"./Scripts/test-package.sh {package}"), 1)
                    self.assertFalse(any("--build-only" in command for command in commands))
                if package == "TrinketFeatureSupport" and smoke is None:
                    self.assertNotIn("./Scripts/build.sh", commands)
                if smoke:
                    self.assertIn(smoke, result.stdout)

    def test_missing_check_retains_failure_evidence_and_stops_before_later_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts)
            (scripts / 'test-scripts.sh').unlink()
            (scripts / 'cheap-fixture.sh').write_text('#!/bin/bash\nprintf ran > later-check\n')
            (scripts / 'cheap-fixture.sh').chmod(0o755)
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            result = subprocess.run([str(scripts / 'handoff.sh'), '--quiet', '--paths', 'Scripts/test-scripts.sh'],
                                    env=self.verification_environment(RESULTS_DIR=str(root / '.DerivedData/HandoffResults')),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertFalse((root / 'later-check').exists())
            logs = list((root / '.DerivedData/HandoffResults').glob('handoff.*/phase-*.log'))
            self.assertEqual(len(logs), 1)
            self.assertIn('Could not start', logs[0].read_text())

    def test_style_preview_and_execution_preserve_literal_file_arguments(self) -> None:
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts)
            path = 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/Probe $cash; literal.swift'
            source = root / path
            source.parent.mkdir(parents=True)
            source.write_text('struct Probe {}')
            (scripts / 'test.sh').write_text('#!/usr/bin/env python3\nimport json, pathlib, sys\npathlib.Path("arguments.json").write_text(json.dumps(sys.argv[1:]))\n')
            (scripts / 'cheap-fixture.sh').write_text('#!/bin/bash\nexit 0\n')
            (scripts / 'cheap-fixture.sh').chmod(0o755)
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            command = [str(scripts / 'handoff.sh'), '--quiet', '--paths', path]
            preview = subprocess.run([command[0], '--dry-run', *command[1:]], env=self.verification_environment(), capture_output=True, text=True)
            self.assertEqual(preview.returncode, 0, preview.stderr)
            style = next(line.strip() for line in preview.stdout.splitlines() if line.strip().startswith('./Scripts/test.sh style'))
            result = subprocess.run(command, env=self.verification_environment(), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads((root / 'arguments.json').read_text()), ['style', path])
            self.assertEqual(shlex.split(style)[1:], ['style', path])

    def test_shared_fixture_verification_routes(self) -> None:
        content_support = "Packages/TrinketContent/Sources/TrinketContentTestSupport"
        combatant = f"{content_support}/CombatantFixtures.swift"
        item = f"{content_support}/ItemFixtures.swift"
        party = f"{content_support}/BattlePartyFixtures.swift"
        consumers = {"BattleEngine", "TrinketAppState", "TrinketBattleFeature", "TrinketFeatureSupport"}
        cases = [
            ("combatant", [combatant], consumers | {"TrinketContent"}, False, False),
            ("item", [item], consumers | {"TrinketContent"}, False, False),
            ("party", [party], consumers | {"TrinketContent"}, False, False),
            ("content-manifest", ["Packages/TrinketContent/Package.swift"], {"TrinketContent"}, False, True),
            ("deleted", [f"{content_support}/DeletedFixture.swift"], consumers | {"TrinketContent"}, False, False),
            ("deduplicated", [combatant, item, party, "Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift"], consumers | {"TrinketContent"}, False, False),
            ("mixed-app", [party, "Trinket/App/TrinketApp.swift"], consumers | {"TrinketContent"}, True, False),
            ("docs", ["Docs/Platform/Testing.md"], set(), False, False),
        ]
        for name, paths, expected_packages, app_build, generation in cases:
            with self.subTest(case=name):
                result = subprocess.run(
                    [str(ROOT / "Scripts/handoff.sh"), "--isolate", "--dry-run", "--smoke", "--paths", *paths],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                plan = result.stdout
                package_commands = re.findall(r"^\s*(?:SKIP_GENERATE=1 )?\./Scripts/test-package\.sh (.+)$", plan, re.MULTILINE)
                packages = [package for command in package_commands for package in command.split()]
                self.assertEqual(set(packages), expected_packages)
                self.assertEqual(len(packages), len(expected_packages))
                self.assertEqual("./Scripts/build.sh" in plan, app_build and shutil.which("xcodebuild") is not None)
                self.assertEqual("./Scripts/generate.sh" in plan, generation)
                self.assertEqual("./Scripts/assert-generated-output.sh --idempotent" in plan, generation)
                self.assertNotIn("./Scripts/test.sh smoke", plan)
                if name == "docs":
                    self.assertIn("./Scripts/check-docs.py", plan)
                    self.assertNotIn("./Scripts/test.sh style", plan)

    def test_handoff_reports_unavailable_compilation_after_available_checks(self) -> None:
        from script_test_support import load_script
        verify = load_script('fixture_verifier', 'verify.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            shutil.copytree(ROOT / 'Scripts', scripts)
            source = root / 'Trinket/App/ContentView.swift'
            source.parent.mkdir(parents=True)
            source.write_text('struct ContentView {}')
            (scripts / 'test.sh').write_text('#!/bin/bash\nprintf style > checks\n')
            (scripts / 'config/cheap-slices.txt').write_text('./Scripts/cheap-fixture.sh\n')
            (scripts / 'cheap-fixture.sh').write_text('#!/bin/bash\nprintf cheap >> checks\n')
            (scripts / 'cheap-fixture.sh').chmod(0o755)
            for dry in (False, True):
                with patch.dict(os.environ, self.verification_environment(hosted=True), clear=True), patch.object(verify.shutil, 'which', return_value=None), contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
                    status = verify.main(['--quiet', *(['--dry-run'] if dry else []), '--paths', 'Trinket/App/ContentView.swift'], root=root)
                self.assertEqual(status, 0 if dry else 2)
                self.assertNotIn('Handoff PASS', output.getvalue())
                if dry:
                    self.assertIn('Unavailable required check', output.getvalue())
                else:
                    self.assertIn('INCOMPLETE', errors.getvalue())
                    self.assertEqual((root / 'checks').read_text(), 'stylecheap')

    def test_handoff_reports_outcome_after_all_checks_including_quiet_mode(self) -> None:
        for selected, cheap, expected in ((0, 0, 0), (7, 0, 7), (0, 8, 8)):
            with self.subTest(selected=selected, cheap=cheap), tempfile.TemporaryDirectory() as directory:
                scripts = Path(directory) / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts)
                payload = "selected-check\n" * 200 + "FAIL: fixture diagnostic\n" if selected else "selected-check\n"
                (scripts / "test-scripts.sh").write_text(f"#!/bin/bash\ncat <<'PAYLOAD'\n{payload}PAYLOAD\nexit {selected}\n")
                registry = scripts / "config/cheap-slices.txt"
                (scripts / 'cheap-fixture.sh').write_text(f'#!/bin/bash\necho cheap-check\nexit {cheap}\n')
                (scripts / 'cheap-fixture.sh').chmod(0o755)
                registry.write_text('./Scripts/cheap-fixture.sh\n')
                result = subprocess.run(
                    [str(scripts / "handoff.sh"), "--quiet", "--paths", "Scripts/test-scripts.sh"],
                    env={**os.environ, "TRINKET_CHEAP_SLICES_CONFIG": str(registry), "GITHUB_ACTIONS": "true",
                         "RESULTS_DIR": str(Path(directory) / ".DerivedData/HandoffResults"),
                         "TRINKET_CLEANUP_TEST_ARTIFACTS": "1", "TRINKET_KEEP_REPORTS": "0"},
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected == 0:
                    self.assertTrue(result.stdout.strip().endswith("Handoff PASS: selected checks and cheap CI slices completed."))
                    self.assertLess(result.stdout.index("Handoff phase PASS: cheap CI slice"), result.stdout.index("Handoff PASS"))
                    self.assertNotIn("selected-check", result.stdout)
                    self.assertNotIn("cheap-check", result.stdout)
                    logs = Path(next(line.removeprefix("Handoff logs: ") for line in result.stdout.splitlines()
                                     if line.startswith("Handoff logs: ")))
                    self.assertFalse(logs.exists(), "successful output must be removed after the outcome")
                else:
                    self.assertNotIn("Handoff PASS", result.stdout)
                    self.assertIn("Handoff FAIL", result.stderr)
                    self.assertIn("./Scripts/test-scripts.sh" if selected else "./Scripts/cheap-fixture.sh", result.stderr)
                    log = Path(next(line.removeprefix("Full log: ") for line in result.stderr.splitlines()
                                    if line.startswith("Full log: ")))
                    self.assertEqual(log.read_text(), payload if selected else "cheap-check\n")
                    self.assertLess(len(result.stderr.splitlines()), 70)
                    retry = next(line.removeprefix('Rerun: ') for line in result.stderr.splitlines() if line.startswith('Rerun: '))
                    self.assertEqual(shlex.split(retry), ['./Scripts/handoff.sh', '--quiet', '--paths', 'Scripts/test-scripts.sh'])
                    if selected:
                        self.assertIn("FAIL: fixture diagnostic", result.stderr)
                        self.assertIn("output omitted", result.stderr)
                    if selected:
                        self.assertNotIn("cheap-check", result.stdout)

if __name__ == "__main__":
    unittest.main()
