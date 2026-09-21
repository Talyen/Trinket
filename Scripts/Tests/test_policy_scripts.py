from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-watch-ci.sh',
    'Scripts/check-api-bans.sh',
    'Scripts/check-module-boundaries.sh',
    'Scripts/ci-infra-rerun.sh',
    'Scripts/format-dirs.env',
    'Scripts/release-notes.sh',
    'Scripts/check-agent-invariants.sh',
    'Scripts/check-exclusivity-footguns.sh',
    'Scripts/lib/rg-check.sh',
)

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
from script_test_support import ScriptRegressionTestCase, ROOT


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


    def test_style_gate_invokes_agent_invariants_and_accessibility_ids(self) -> None:
        text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        style_lib = (ROOT / "Scripts" / "lib" / "test-style.sh").read_text(encoding="utf-8")
        combined = text + style_lib
        self.assertIn("check-agent-invariants.sh", combined)
        self.assertIn("check-accessibility-ids.py", combined)


    def test_format_roots_derived_from_packages(self) -> None:
        text = (ROOT / "Scripts" / "format-dirs.env").read_text()
        self.assertIn("TRINKET_TEST_PACKAGES", text)
        self.assertNotIn("Packages/TrinketCore/Tests", text)
