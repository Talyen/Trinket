#!/usr/bin/env python3
"""Focused regressions for script safety checks."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "Scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class ScriptRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.codegen = load_script("content_codegen", "content_codegen.py")

    def test_publicize_ignores_braces_in_string_literals(self) -> None:
        source = 'struct Thing {\n    let brace = "}"\n    let value = 1\n}\n'
        output = self.codegen.publicize(source)
        self.assertIn("public let value = 1", output)

    def test_homestead_prerequisite_tier_must_exist(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.validate_homestead_prerequisites(
                "wheatField:9", "orchard-tier-1", {"wheatField": {1, 2}}
            )

    def test_content_codegen_rejects_unknown_command(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "Scripts" / "content_codegen.py"), "typo"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown command", result.stderr)

    def test_prepare_asset_scripts_use_c_locale_header_preserving_sort(self) -> None:
        scripts = (
            "prepare-app-icon.sh",
            "prepare-music-assets.sh",
            "prepare-sfx-assets.sh",
            "prepare-cinematic-assets.sh",
            "prepare-art-assets.sh",
        )
        for name in scripts:
            text = (ROOT / "Scripts" / name).read_text(encoding="utf-8")
            self.assertIn("LC_ALL=C sort", text, name)
            self.assertTrue(
                ("head -n 2" in text and "tail -n +3" in text) or ("tail -n +3" in text),
                f"{name} should preserve hash TSV headers before sorting",
            )

    def test_generate_pins_c_locale(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("export LC_ALL=C", text)
        self.assertIn("export LANG=C", text)

    def test_generate_pins_xcode_macos_sdk(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("ensure_xcode_macos_sdk", text)
        self.assertIn("export DEVELOPER_DIR=", text)
        self.assertIn("export SDKROOT=", text)
        self.assertIn("CommandLineTools", text)

    def test_generate_requires_xcodegen(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("xcodegen not found on PATH", text)
        self.assertNotIn("python3 Scripts/sync-xcodeproj-sources.py", text)
        self.assertFalse((ROOT / "Scripts" / "sync-xcodeproj-sources.py").exists())

    def test_build_inputs_include_xctestplans(self) -> None:
        text = (ROOT / "Scripts" / "build-inputs.sh").read_text(encoding="utf-8")
        for plan in (
            "Unit.xctestplan",
            "Smoke.xctestplan",
            "QuickSmoke.xctestplan",
            "FullUI.xctestplan",
            "Integration.xctestplan",
            "BattlePerformance.xctestplan",
        ):
            self.assertIn(plan, text)
        self.assertNotIn("Package.resolved", text)

    def test_authored_content_swift_routes_generation_style_and_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
                "--paths",
                "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        self.assertEqual(
            plan,
            [
                "./Scripts/generate.sh",
                "./Scripts/assert-generated-output.sh --idempotent",
                "./Scripts/test.sh style Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift",
                "./Scripts/test-package.sh TrinketContent",
            ],
        )

    def test_prune_gates_bulk_wipe(self) -> None:
        text = (ROOT / "Scripts" / "prune-derived-data-cache.sh").read_text(encoding="utf-8")
        self.assertIn('CI_MODE=true', text)
        self.assertIn("--ci", text)
        self.assertIn("Skipping Intermediate/compilation-cache wipe", text)

    def test_run_env_self_cleans_on_start_and_release(self) -> None:
        text = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        self.assertIn("trinket_preview_sims_reclaim", text)
        self.assertIn("trinket_simulator_enforce_single_warm_booted", text)
        self.assertIn("trinket_derived_data_age_prune", text)
        self.assertIn("trinket_run_env_self_clean_hygiene", text)
        self.assertIn("trinket_run_env_release_slots", text)
        self.assertIn("trinket_run_env_claim_self_clean_owner", text)
        self.assertIn("TRINKET_SELF_CLEAN_OWNER", text)
        self.assertIn("Simulator%20Devices", text)
        self.assertIn("Packages", text)
        hygiene = text.split("trinket_run_env_self_clean_hygiene()", 1)[1].split(
            "trinket_run_env_claim_self_clean_owner", 1
        )[0]
        self.assertIn("trinket_preview_sims_reclaim", hygiene)
        self.assertIn("trinket_simulator_enforce_single_warm_booted", hygiene)
        self.assertIn("trinket_derived_data_age_prune", hygiene)
        install = text.split("trinket_run_env_install_self_clean()", 1)[1].split(
            "trinket_run_env_install_test_simulator_cleanup", 1
        )[0]
        self.assertIn("trinket_run_env_self_clean_hygiene", install)
        release = text.split("trinket_run_env_release_slots()", 1)[1].split(
            "trinket_run_env_install_release_trap", 1
        )[0]
        self.assertIn("TRINKET_SELF_CLEAN_OWNER", release)
        self.assertIn("trinket_run_env_self_clean_hygiene", release)
        single = text.split("trinket_simulator_enforce_single_warm_booted()", 1)[1].split(
            "trinket_simulator_cleanup_excess", 1
        )[0]
        self.assertIn('TRINKET_CLEANUP_SINGLE_WARMED:-1', single)
        self.assertIn("Trinket CI", single)
        self.assertIn(r"Trinket Agent \d+", single)
        idle = text.split("trinket_simulator_cleanup_idle_pool()", 1)[1].split(
            "trinket_simulator_enforce_single_warm_booted", 1
        )[0]
        self.assertIn(r"Trinket Agent \d+", idle)
        self.assertIn("Trinket CI stays warm", idle)
        self.assertIn('TRINKET_CLEANUP_IDLE_POOL:-0', idle)
        self.assertNotIn('name == "Trinket CI"', idle)
        self.assertIn('TRINKET_MAX_AGENT_SIMS:-1', text)
        self.assertFalse((ROOT / "Scripts" / "clean-dev-artifacts.sh").exists())

    def test_verify_changed_docs_path_uses_self_clean_hygiene(self) -> None:
        text = (ROOT / "Scripts" / "verify-changed.sh").read_text(encoding="utf-8")
        self.assertIn("trinket_run_env_self_clean_hygiene", text)
        self.assertNotIn("clean-dev-artifacts", text)
        self.assertNotIn("TRINKET_CLEANUP_IDLE_POOL=1 opts", text)


if __name__ == "__main__":
    unittest.main()
