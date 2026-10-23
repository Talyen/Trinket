from __future__ import annotations

from pathlib import Path
from unittest.mock import patch
import tempfile
from script_test_support import ROOT, ScriptRegressionTestCase, load_script, run_captured, run_python


class UiPolicyTests(ScriptRegressionTestCase):
    def test_ui_style_requires_explicit_catalog_artwork_display_size(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ArtworkFixture.swift"
            fixture.write_text(
                "Image.preparedAsset(named: art.imageName)\n",
                encoding="utf-8",
            )
            rejected = run_python('check-ui-style.py', str(fixture), cwd=ROOT)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("catalog artwork without explicit display size", rejected.stdout)

            fixture.write_text(
                "PreparedArtworkImage(art, displaySize: .compact)\n",
                encoding="utf-8",
            )
            run_python('check-ui-style.py', str(fixture), cwd=ROOT, expected=0)


    def test_ui_style_rejects_thumbnail_renderer_bypasses(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ArtworkFixture.swift"
            for source, diagnostic in (
                ("Image.preparedAsset(art, displaySize: .compact)", "must use PreparedArtworkImage"),
                ("Image.preparedAsset(\n art, displaySize: .compact)", "must use PreparedArtworkImage"),
                ("image.interpolation(.low)", "low quality image interpolation"),
            ):
                with self.subTest(source=source):
                    fixture.write_text(source + "\n", encoding="utf-8")
                    rejected = run_python('check-ui-style.py', str(fixture), cwd=ROOT)
                    self.assertNotEqual(rejected.returncode, 0)
                    self.assertIn(diagnostic, rejected.stdout)


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
                rejected = run_python('check-ui-style.py', str(fixture), cwd=ROOT)
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
            with patch.object(checker.subprocess, "run", side_effect=FileNotFoundError), \
                    patch.object(Path, "read_text", side_effect=PermissionError("unreadable source")), \
                    patch("builtins.print"):
                self.assertEqual(checker.main(["check-ui-style.py", directory]), 1)


    def test_artwork_budget_uses_bounded_behavior_tests_and_respects_local_limits(self) -> None:
        from script_test_support import write_executable
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, ("Scripts/check-artwork-budget.sh",))
            write_executable(root / 'Scripts/test-package.sh',
                             '#!/bin/sh\nprintf "%s\\n" "$@" > arguments.txt\nprintf "%s" "$TRINKET_ISOLATE" > isolation.txt\n')
            command = [str(root / 'Scripts/check-artwork-budget.sh')]
            run_captured([*command, '--help'], cwd=root, env=self.verification_environment(), expected=0)
            self.assertFalse((root / 'arguments.txt').exists())
            rejected = run_captured(command, cwd=root, env=self.verification_environment())
            self.assertEqual(rejected.returncode, 2, rejected.stdout + rejected.stderr)
            self.assertFalse((root / 'arguments.txt').exists())
            run_captured(command, cwd=root,
                         env=self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL='1'), expected=0)
            self.assertEqual((root / 'isolation.txt').read_text(), '1')
            self.assertEqual((root / 'arguments.txt').read_text().splitlines(),
                             ['--only-suite', 'PreparedArtworkCacheTests', 'TrinketFeatureSupport'])

    def test_accessibility_ids_failure_fixture_rejects_duplicates_and_raw_literals(self) -> None:
        checker = load_script("check_accessibility_ids", "check-accessibility-ids.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ids = root / "AccessibilityID.swift"
            ids.write_text(
                "public enum AccessibilityID {\n"
                '  public static let playButton = "play-button"\n'
                "}\n",
                encoding="utf-8",
            )
            (root / "AccessibilityID+Battle.swift").write_text(
                'extension AccessibilityID { public static let playButtonAlias = "play-button" }\n'
            )
            uitests = root / "UITests"
            uitests.mkdir()
            (uitests / "ProbeTests.swift").write_text(
                "import XCTest\n"
                "final class ProbeTests: XCTestCase {\n"
                "  func testProbe() {\n"
                '    app.buttons[AccessibilityID.playButton].tap(); app.buttons["play-button"].tap()\n'
                '    app.alerts["System prompt"].tap()\n'
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            with patch.object(checker, "ROOT", root), patch.object(checker, "ID_FILE", ids), patch.object(checker, "UITESTS", uitests):
                self.assertEqual(checker.unique_constants(), ["play-button"])
                raw, _ = checker.uitest_findings({"System prompt"})
                self.assertEqual(len(raw), 1)
                self.assertIn("play-button", raw[0])

    def test_ui_style_checks_paths_with_colons_and_newlines(self) -> None:
        checker = load_script("check_ui_style", "check-ui-style.py")
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "Color:fixture\nprobe.swift"
            fixture.write_text("let color = Color.red\n")
            with patch("builtins.print"):
                self.assertEqual(checker.main(["check-ui-style.py", str(fixture)]), 1)
