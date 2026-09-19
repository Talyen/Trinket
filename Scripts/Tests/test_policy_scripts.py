from __future__ import annotations

from pathlib import Path
from unittest.mock import patch
import os
import shutil
import subprocess
import sys
import tempfile

from script_test_support import ROOT, ScriptRegressionTestCase, load_script


class PolicyScriptsTests(ScriptRegressionTestCase):
    def test_shell_policy_checks_reject_search_errors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_rg = Path(directory) / "rg"
            fake_rg.write_text('#!/bin/sh\nexit "$SEARCH_STATUS"\n')
            fake_rg.chmod(0o755)
            for name in ("api-bans", "agent-invariants", "exclusivity-footguns", "module-boundaries"):
                for status in (1, 2):
                    with self.subTest(check=name, status=status):
                        result = subprocess.run(
                            [str(ROOT / f"Scripts/check-{name}.sh")], cwd=ROOT,
                            env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}", "SEARCH_STATUS": str(status)},
                            capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, 0 if status == 1 else 2, result.stdout + result.stderr)

    def test_ui_style_requires_explicit_catalog_artwork_display_size(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ArtworkFixture.swift"
            fixture.write_text(
                "Image.preparedAsset(named: art.imageName)\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-ui-style.py"), str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("catalog artwork without explicit display size", rejected.stdout)

            fixture.write_text(
                "Image.preparedAsset(art, displaySize: .compact)\n",
                encoding="utf-8",
            )
            accepted = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-ui-style.py"), str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout + accepted.stderr)

    def test_ui_style_owns_product_color_policy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ColorFixture.swift"
            for source in (
                "let color = Color(red: 1, green: 0, blue: 0)\n",
                "let color = Color.red\n",
                "Text(\"Alert\").foregroundStyle(.red)\n",
                'let color = Color("Alert", bundle: .main)\n',
            ):
                fixture.write_text(source, encoding="utf-8")
                rejected = subprocess.run(
                    [sys.executable, str(ROOT / "Scripts" / "check-ui-style.py"), str(fixture)],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(rejected.returncode, 0, source)

        swiftlint = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        platform = (ROOT / "Scripts" / "check-api-bans.sh").read_text(encoding="utf-8")
        self.assertNotIn("banned_system_color_literal", swiftlint)
        self.assertNotIn("SYSTEM_COLORS", platform)

    def test_ui_style_scans_directories_without_ripgrep(self) -> None:
        checker = load_script("check_ui_style", "check-ui-style.py")
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "Nested" / "Style.swift"
            fixture.parent.mkdir()
            for source, expected in (("let color = Color.red\n", 1), ("let color = Color.primary\n", 0)):
                with self.subTest(source=source), patch.object(checker.subprocess, "run", side_effect=FileNotFoundError), patch("builtins.print"):
                    fixture.write_text(source)
                    self.assertEqual(checker.main(["check-ui-style.py", directory]), expected)

    def test_comment_rationale_preserves_suppression_and_concurrency_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-agent-invariants.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env", "internal/swift_policy.py", "tool-versions.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            (root / ".tools").symlink_to(ROOT / ".tools", target_is_directory=True)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "Trinket/App").mkdir(parents=True)
            (root / "TrinketUITests").mkdir()
            (root / "Trinket/App/TrinketApp.swift").write_text("import SwiftUI\n")
            fixture = root / "Trinket/Probe.swift"
            cases = (
                ("// Preserve ordering across suspension.\n/* The callback owns its lifetime. */\nstruct Probe {}\n", None),
                ("// swiftlint:disable type_body_length\nstruct Probe {}\n", "swiftlint:disable must include"),
                ("// swiftlint:disable type_body_length - cohesive fixture\nstruct Probe {}\n", None),
                ("final class Probe: @unchecked Sendable {}\n", "needs a nearby Concurrency-Safety"),
                ("// Concurrency-Safety: immutable fields never change after initialization\n"
                 "final class Probe: @unchecked Sendable {}\n", None),
            )
            for source, failure in cases:
                with self.subTest(source=source):
                    fixture.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-agent-invariants.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_agent_invariants_reject_unseeded_entropy_sleep_try_and_pin_release(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-agent-invariants.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env", "internal/swift_policy.py", "tool-versions.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            (root / ".tools").symlink_to(ROOT / ".tools", target_is_directory=True)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "Trinket/App").mkdir(parents=True)
            (root / "TrinketUITests").mkdir()
            engine_probe = root / "Packages/BattleEngine/Sources/BattleEngine/Probe.swift"
            sleep_probe = root / "Packages/BattleEngine/Tests/ProbeTests.swift"
            persistence_probe = root / "Packages/TrinketPersistence/Sources/TrinketPersistence/Probe.swift"
            app_main = root / "Trinket/App/TrinketApp.swift"

            def run_checker() -> subprocess.CompletedProcess[str]:
                return subprocess.run([str(root / "Scripts/check-agent-invariants.sh")],
                                        cwd=root, capture_output=True, text=True)

            clean = (
                (engine_probe, "struct Probe {}\n"),
                (sleep_probe, "import Testing\nstruct ProbeTests {}\n"),
                (persistence_probe, "struct Probe {}\n"),
                (app_main, "import SwiftUI\nstruct TrinketApp {}\n"),
            )
            cases = (
                ("unseeded Date",
                 ((engine_probe, "struct Probe { let now = Date() }\n"),), "unseeded Date()/UUID()"),
                ("allowed Date",
                 ((engine_probe, "// EntropyCheck: allow - deterministic fixture\nstruct Probe { let now = Date() }\n"),), None),
                ("unseeded random",
                 ((engine_probe, "struct Probe { let roll = Int.random(in: 1...6) }\n"),), "unseeded .random("),
                ("injected random",
                 ((engine_probe, "struct Probe { let roll = rng.random(in: 1...6, using: &generator) }\n"),), None),
                ("blocking Task.sleep",
                 ((sleep_probe, "import Testing\nstruct ProbeTests { func run() async { try? await Task.sleep(nanoseconds: 1_000) } }\n"),), "Task.sleep"),
                ("millisecond Task.sleep",
                 ((sleep_probe, "import Testing\nstruct ProbeTests { func run() async { try? await Task.sleep(.milliseconds(10)) } }\n"),), None),
                ("silent persistence try",
                 ((persistence_probe, "struct Probe { func load() { try? store.load() } }\n"),), "try? on persistence"),
                ("allowed persistence try",
                 ((persistence_probe, "// PersistenceCheck: allow - best-effort cache warm\nstruct Probe { func load() { try? store.load() } }\n"),), None),
                ("released artwork pins",
                 ((app_main, "import SwiftUI\nstruct TrinketApp { func reset() { view.releasePins() } }\n"),), "do not release launch artwork pins"),
            )
            for label, overwrites, failure in cases:
                with self.subTest(label=label):
                    for path, _ in clean:
                        path.write_text(dict(clean)[path])
                    for path, source in overwrites:
                        path.write_text(source)
                    result = run_checker()
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_exclusivity_footguns_reject_self_inout_and_honor_allow(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-exclusivity-footguns.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "TrinketUITests").mkdir()
            fixture = root / "Trinket/Probe.swift"
            fixture.parent.mkdir(parents=True)
            cases = (
                ("explicit self inout",
                 "struct Holder {\n  var count = 0\n  func bump() {\n    take(&self.count)\n  }\n}\n",
                 "&self.count"),
                ("allowed self inout",
                 "struct Holder {\n  var count = 0\n  func bump() {\n    // ExclusivityCheck: allow - copied to a local before the call\n    take(&self.count)\n  }\n}\n",
                 None),
                ("stored into without local",
                 "struct Runner {\n  var stored = 0\n  func run() {\n    apply(into: &stored)\n  }\n}\n",
                 "into: &stored"),
                ("into with function-local var",
                 "struct Runner {\n  func run() {\n    var stored = 0\n    apply(into: &stored)\n  }\n}\n",
                 None),
            )
            for label, source, failure in cases:
                with self.subTest(label=label):
                    fixture.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-exclusivity-footguns.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_artwork_budget_enforces_constants_and_rejects_96_floor(self) -> None:
        live = (ROOT / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-artwork-budget.sh", "lib/rg-check.sh"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            fixture = root / "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift"
            fixture.parent.mkdir(parents=True)
            cases = (
                ("live constants pass", live, None),
                ("resident drift",
                 live.replace("320 * 1024 * 1024", "321 * 1024 * 1024"), "residentArtworkByteCount must be 320"),
                ("steady drift",
                 live.replace("550 * 1024 * 1024", "551 * 1024 * 1024"), "steadyStateProcessByteCount must be 550"),
                ("floor lowered to 96",
                 live.replace("160 * 1024 * 1024", "96 * 1024 * 1024"), "96 MiB floor"),
                ("cap lowered",
                 live.replace("260 * 1024 * 1024", "160 * 1024 * 1024"), "NSCache cap must be 260"),
            )
            for label, source, failure in cases:
                with self.subTest(label=label):
                    fixture.write_text(source, encoding="utf-8")
                    result = subprocess.run([str(root / "Scripts/check-artwork-budget.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_module_boundaries_reject_upward_imports_and_allowlist_battle_seams(self) -> None:
        manifest = (
            "// swift-tools-version: 6.4\n"
            "import PackageDescription\n"
            "let package = Package(name: \"Probe\", targets: [.target(name: \"Probe\")])\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-module-boundaries.sh", "lib/rg-check.sh"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            for package in ("TrinketDesignSystem", "BattleEngine", "TrinketPersistence",
                            "TrinketFeatureSupport", "TrinketBattleFeature", "TrinketAppState"):
                (root / "Packages" / package / "Sources" / package).mkdir(parents=True)
                (root / "Packages" / package / "Package.swift").write_text(manifest)
            design_probe = root / "Packages/TrinketDesignSystem/Sources/Probe.swift"
            appstate_manifest = root / "Packages/TrinketAppState/Package.swift"
            seam = root / "Trinket/Features/Play/PlayView.swift"
            outsider = root / "Trinket/Features/Play/OutsiderView.swift"
            seam.parent.mkdir(parents=True)
            clean = (
                (design_probe, "struct Probe {}\n"),
                (seam, "import TrinketBattleFeature\nstruct PlayView {}\n"),
                (outsider, "struct OutsiderView {}\n"),
                (appstate_manifest, manifest),
            )
            appstate_dep = manifest.replace(
                '[.target(name: "Probe")]',
                '[.target(name: "Probe", dependencies: ["TrinketBattleFeature"])]',
            )
            cases = (
                ("clean tree with allowlisted seam", (), None),
                ("design system importing engine",
                 ((design_probe, "import BattleEngine\nstruct Probe {}\n"),),
                 "TrinketDesignSystem must not import BattleEngine"),
                ("app screen outside the battle seams",
                 ((outsider, "import TrinketBattleFeature\nstruct OutsiderView {}\n"),),
                 "must use BattleRuntime/FeatureSupport instead of importing BattleFeature"),
                ("app state depending on battle feature",
                 ((appstate_manifest, appstate_dep),),
                 "production target must depend on BattleEngine, not BattleFeature"),
            )
            for label, overwrites, failure in cases:
                with self.subTest(label=label):
                    for path, source in clean:
                        path.write_text(source)
                    for path, source in overwrites:
                        path.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-module-boundaries.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_accessibility_ids_reject_duplicate_constants_and_raw_uitest_literals(self) -> None:
        checker = load_script("check_accessibility_ids", "check-accessibility-ids.py")
        duplicates = checker.unique_constants()
        self.assertEqual(duplicates, [])
        raw = checker.raw_uitest_literals(checker.allowlist())
        self.assertEqual(raw, [], raw)

    def test_accessibility_ids_failure_fixture_rejects_duplicates_and_raw_literals(self) -> None:
        checker = load_script("check_accessibility_ids", "check-accessibility-ids.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ids = root / "AccessibilityID.swift"
            ids.write_text(
                "public enum AccessibilityID {\n"
                '  public static let playButton = "play-button"\n'
                '  public static let playButtonAlias = "play-button"\n'
                "}\n",
                encoding="utf-8",
            )
            uitests = root / "UITests"
            uitests.mkdir()
            (uitests / "ProbeTests.swift").write_text(
                "import XCTest\n"
                "final class ProbeTests: XCTestCase {\n"
                "  func testProbe() {\n"
                '    app.buttons["play-button"].tap()\n'
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            with patch.object(checker, "ROOT", root), patch.object(checker, "ID_FILE", ids), patch.object(checker, "UITESTS", uitests):
                self.assertEqual(checker.unique_constants(), ["play-button"])
                raw = checker.raw_uitest_literals(set())
                self.assertEqual(len(raw), 1)
                self.assertIn("play-button", raw[0])

    def test_style_gate_invokes_agent_invariants_and_accessibility_ids(self) -> None:
        text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        style_lib = (ROOT / "Scripts" / "lib" / "test-style.sh").read_text(encoding="utf-8")
        combined = text + style_lib
        self.assertIn("check-agent-invariants.sh", combined)
        self.assertIn("check-accessibility-ids.py", combined)
