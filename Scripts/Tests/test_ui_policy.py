from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/check-ui-style.py',
    'Scripts/check-artwork-budget.sh',
    'Scripts/check-accessibility-ids.py',
    'Scripts/config/system-colors.txt',
    'Scripts/config/uitest-system-query-allowlist.txt',
)

from pathlib import Path
from unittest.mock import patch
import shutil
import subprocess
import sys
import tempfile
from script_test_support import ScriptRegressionTestCase, ROOT, load_script


class UiPolicyTests(ScriptRegressionTestCase):
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
