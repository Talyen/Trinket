#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-gate.sh',
    'Scripts/config/cheap-slices.txt',
    'Scripts/handoff.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/gate.sh',
)


import re
import shutil
import subprocess
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase

import os
import tempfile
from pathlib import Path

class CIHandoffRoutingTests(ScriptRegressionTestCase):
    def test_mystery_subflow_runs_play_smoke(self) -> None:
        # Deterministic routing: when --smoke is passed, any Play diff runs SmokeShellTests.
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Trinket/Features/Play/Mystery/MysteryChoiceCard.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokeShellTests", result.stdout)

    def test_play_shell_keeps_smoke_shell(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Trinket/Features/Play/Modes/PlayModeHubView.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokeShellTests", result.stdout)

    def test_feature_support_generic_skips_app_build_when_package_tests_run(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/HomesteadResourceArtwork.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/test-package.sh TrinketFeatureSupport", plan)
        self.assertNotIn("./Scripts/build.sh", plan)

    def test_accessibility_id_keeps_shell_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokeShellTests", result.stdout)

    def test_prepared_artwork_keeps_shell_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokeShellTests", result.stdout)

    def test_battle_feature_lab_runs_full_package_tests_and_smoke(self) -> None:
        # With --smoke, a DEBUG variant file runs the full package
        # suite plus the SmokeBattleTests canary.
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Effects/CombatantCardDeathEffectVariants.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/test-package.sh TrinketBattleFeature", plan)
        self.assertNotIn("--build-only", plan)
        self.assertIn("SmokeBattleTests", plan)

    def test_battle_feature_shipping_keeps_package_tests_and_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Battlefield/BattleCombatantPane.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/test-package.sh TrinketBattleFeature", plan)
        self.assertNotIn("--build-only TrinketBattleFeature", plan)
        self.assertIn("SmokeBattleTests", plan)

    def test_battle_feature_lab_plus_shipping_keeps_full_package_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--smoke",
                "--paths",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Effects/CombatantCardDeathEffectVariants.swift",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Battlefield/BattleCombatantPane.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/test-package.sh TrinketBattleFeature", plan)
        self.assertNotIn("--build-only TrinketBattleFeature", plan)
        self.assertIn("SmokeBattleTests", plan)

    def test_battle_runtime_routes_to_app_build_not_test_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Packages/BattleEngine/Sources/BattleEngine/Runtime/BattleRuntime.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("test-package.sh BattleEngine", plan)

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
                package_commands = re.findall(r"^\s*\./Scripts/test-package\.sh (.+)$", plan, re.MULTILINE)
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
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            source = root / "Trinket/App/ContentView.swift"
            source.parent.mkdir(parents=True)
            source.write_text("struct ContentView {}")
            (scripts / "test.sh").write_text('#!/bin/bash\n./Scripts/check-api-bans.sh\necho style-checked\n')
            (scripts / "check-api-bans.sh").write_text('#!/bin/bash\necho api >> checks\n')
            (scripts / "config/cheap-slices.txt").write_text('./Scripts/check-api-bans.sh  # skip-when-style-checked\necho cheap-checked\n')
            startup = root / "startup"
            startup.write_text('command() { if [[ "$*" == "-v xcodebuild" ]]; then return 1; fi; builtin command "$@"; }\n')
            environment = {**os.environ, "BASH_ENV": str(startup)}
            for dry in (False, True):
                result = subprocess.run([str(scripts / "handoff.sh"), *(["--dry-run"] if dry else []),
                                         "--paths", "Trinket/App/ContentView.swift"],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if dry else 2, result.stdout + result.stderr)
                self.assertNotIn("Handoff PASS", result.stdout)
                if dry:
                    self.assertIn("Unavailable required check", result.stdout)
                else:
                    self.assertIn("style-checked", result.stdout)
                    self.assertIn("cheap-checked", result.stdout)
                    self.assertIn("INCOMPLETE", result.stderr)
                    self.assertEqual((root / "checks").read_text(), "api\n")


    def test_handoff_reports_outcome_after_all_checks_including_quiet_mode(self) -> None:
        for selected, cheap, expected in ((0, 0, 0), (7, 0, 1), (0, 8, 8)):
            with self.subTest(selected=selected, cheap=cheap), tempfile.TemporaryDirectory() as directory:
                scripts = Path(directory) / "Scripts"
                shutil.copytree(ROOT / "Scripts", scripts)
                payload = "selected-check\n" * 200 + "FAIL: fixture diagnostic\n" if selected else "selected-check\n"
                (scripts / "test-scripts.sh").write_text(f"#!/bin/bash\ncat <<'PAYLOAD'\n{payload}PAYLOAD\nexit {selected}\n")
                registry = scripts / "config/cheap-slices.txt"
                registry.write_text(f"echo cheap-check; exit {cheap}\n")
                result = subprocess.run(
                    [str(scripts / "handoff.sh"), "--quiet", "--paths", "Scripts/test-scripts.sh"],
                    env={**os.environ, "TRINKET_CHEAP_SLICES_CONFIG": str(registry)},
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected == 0:
                    self.assertTrue(result.stdout.strip().endswith("Handoff PASS: selected checks and cheap CI slices completed."))
                    self.assertLess(result.stdout.index("Handoff phase PASS: cheap CI slices"), result.stdout.index("Handoff PASS"))
                    self.assertNotIn("selected-check", result.stdout)
                    self.assertNotIn("cheap-check", result.stdout)
                    logs = Path(next(line.removeprefix("Handoff logs: ") for line in result.stdout.splitlines()
                                     if line.startswith("Handoff logs: ")))
                    self.assertEqual((logs / "phase-1.log").read_text(), "selected-check\n")
                    self.assertEqual((logs / "phase-2.log").read_text(), "cheap-check\n")
                else:
                    self.assertNotIn("Handoff PASS", result.stdout)
                    self.assertIn("Handoff FAIL", result.stderr)
                    self.assertIn("./Scripts/test-scripts.sh" if selected else "cheap CI slices", result.stderr)
                    log = Path(next(line.removeprefix("Full log: ") for line in result.stderr.splitlines()
                                    if line.startswith("Full log: ")))
                    self.assertEqual(log.read_text(), payload if selected else "cheap-check\n")
                    self.assertLess(len(result.stderr.splitlines()), 70)
                    if selected:
                        self.assertIn("FAIL: fixture diagnostic", result.stderr)
                        self.assertIn("output omitted", result.stderr)
                    if selected:
                        self.assertNotIn("cheap-check", result.stdout)



if __name__ == "__main__":
    unittest.main()
