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
            self.assertIn(
                "cmp -s",
                text,
                f"{name} should skip rewriting unchanged hash/catalog stamps",
            )

    def test_prepare_art_skips_unchanged_catalog_contents_json(self) -> None:
        text = (ROOT / "Scripts" / "prepare-art-assets.sh").read_text(encoding="utf-8")
        self.assertIn("contents_json_temp", text)
        self.assertIn('"$asset_catalog/Contents.json"', text)
        self.assertRegex(
            text,
            r"cmp -s \"\$contents_json_temp\" \"\$asset_catalog/Contents\.json\"",
        )

    def test_project_yml_keeps_assets_outside_swift_sync_roots(self) -> None:
        text = (ROOT / "project.yml").read_text(encoding="utf-8")
        self.assertIn("path: Trinket/App", text)
        self.assertIn("type: syncedFolder", text)
        self.assertIn("path: Trinket/Assets.xcassets", text)
        self.assertIn("path: Trinket/Media", text)
        self.assertIn("path: Trinket/AppIcon.icon", text)
        # Whole-folder sync of Trinket/ would pull assets into the FS sync root.
        self.assertNotRegex(
            text,
            r"(?m)^\s+- path: Trinket\n\s+type: syncedFolder\n",
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

    def test_build_cache_paths_aligned(self) -> None:
        result = subprocess.run(
            [str(ROOT / "Scripts" / "check-build-cache-paths.sh")],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("aligned", result.stdout)

    def test_ci_assets_gate_locale_rerun(self) -> None:
        text = (ROOT / "Scripts" / "ci-assets-gate.sh").read_text(encoding="utf-8")
        self.assertIn("generate.sh --assets", text)
        self.assertIn("assert-generated-output.sh --assets", text)
        self.assertIn("LC_ALL=en_US.UTF-8", text)
        self.assertIn("LANG=en_US.UTF-8", text)

    def test_restore_and_build_action_owns_cache_prefix(self) -> None:
        text = (
            ROOT / ".github" / "actions" / "restore-and-build" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("build-cache-key", text)
        self.assertIn("build-for-testing.sh", text)
        self.assertIn("prune-derived-data-cache.sh", text)
        workflows = (
            (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8"),
            (ROOT / ".github" / "workflows" / "nightly.yml").read_text(encoding="utf-8"),
        )
        for workflow in workflows:
            self.assertIn("restore-and-build", workflow)
            self.assertNotIn("actions/cache/restore@", workflow)

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

    def test_mystery_subflow_routes_compile_not_smoke_play(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
                "--paths",
                "Trinket/Features/Play/Mystery/MysteryChoiceCard.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/build.sh", plan)
        self.assertNotIn("SmokePlayTests", plan)

    def test_play_shell_keeps_smoke_play(self) -> None:
        # Hub paths always keep SmokePlayTests (PlayView may demote on subflow-only diffs).
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
                "--paths",
                "Trinket/Features/Play/Modes/PlayModeHubView.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokePlayTests", result.stdout)

    def test_play_shell_diff_classifier(self) -> None:
        classifier = load_script("classify_play_shell_diff", "classify-play-shell-diff.py")
        self.assertEqual(
            classifier.classify_changed_lines(
                [
                    "PlayModeHubView()",
                    "accessibilityIdentifier: AccessibilityID.Play.campaignModeCard",
                ]
            ),
            "shell",
        )
        self.assertEqual(
            classifier.classify_changed_lines(
                [
                    "PlayEncounterCoversModifier()",
                    "onResolveChoice: { choiceID in",
                    "encounters.resolveActiveMysteryChoice(choiceID: choiceID)",
                ]
            ),
            "subflow",
        )
        self.assertEqual(
            classifier.classify_changed_lines(
                [
                    "PlayEncounterCoversModifier()",
                    "PlayModeHubView()",
                ]
            ),
            "shell",
        )
        self.assertEqual(
            classifier.classify_changed_lines(["import SwiftUI", "}"]),
            "uncertain",
        )
        self.assertEqual(
            classifier.classify_changed_lines(
                [
                    "onSelectItem: { itemID in",
                    "encounters.selectActiveMysteryItem(itemID: itemID)",
                    "},",
                ]
            ),
            "subflow",
        )

    def test_feature_support_generic_skips_app_build_when_package_tests_run(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
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

    def test_accessibility_id_keeps_homestead_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SmokeHomesteadTests", result.stdout)

    def test_battle_feature_lab_routes_build_only_not_full_package_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
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
        self.assertIn(
            "./Scripts/test-package.sh --build-only TrinketBattleFeature", plan
        )
        self.assertNotIn("./Scripts/test-package.sh TrinketBattleFeature\n", plan + "\n")
        self.assertNotIn("SmokeBattleTests", plan)

    def test_battle_feature_shipping_keeps_package_tests_and_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
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
                str(ROOT / "Scripts" / "verify-changed.sh"),
                "--dry-run",
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

    def test_generate_stamp_records_input_porcelain_sidecar(self) -> None:
        text = (ROOT / "Scripts" / "build-inputs.sh").read_text(encoding="utf-8")
        self.assertIn("touch_generate_stamp", text)
        self.assertIn("record_generate_input_git_snapshot", text)
        self.assertIn("assert_generate_input_git_snapshot_unchanged", text)
        assert_text = (ROOT / "Scripts" / "assert-generated-output.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("assert_generate_input_git_snapshot_unchanged", assert_text)
        self.assertIn("Prefer stamp-time porcelain over dirty-vs-HEAD", assert_text)

    def test_test_package_records_timing_log(self) -> None:
        text = (ROOT / "Scripts" / "test-package.sh").read_text(encoding="utf-8")
        self.assertIn("./Scripts/test-timing.sh record", text)
        self.assertIn('package:$package', text)
        self.assertIn("--xcresult", text)

    def test_test_package_parallelizes_multiple_packages(self) -> None:
        text = (ROOT / "Scripts" / "test-package.sh").read_text(encoding="utf-8")
        self.assertIn("xargs -P", text)
        self.assertIn("package test schemes in parallel", text)
        self.assertIn("per-package DerivedData tenants", text)
        self.assertIn('SYMROOT=$(package_symroot "$package_dd")', text)
        self.assertIn('OBJROOT=$(package_objroot "$package_dd")', text)
        self.assertIn(
            'SHARED_PRECOMPS_DIR=$(package_shared_precomps_dir "$package_dd")', text
        )
        stamp = (ROOT / "Scripts" / "build-stamp.sh").read_text(encoding="utf-8")
        self.assertIn("package_symroot()", stamp)
        self.assertIn("package_objroot()", stamp)
        self.assertIn("package_shared_precomps_dir()", stamp)
        self.assertIn("Packages/.DerivedData", stamp)
        build_for_testing = (ROOT / "Scripts" / "build-for-testing.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('SYMROOT=$(package_symroot "$package_dd")', build_for_testing)
        self.assertIn('OBJROOT=$(package_objroot "$package_dd")', build_for_testing)
        self.assertIn(
            'SHARED_PRECOMPS_DIR=$(package_shared_precomps_dir "$package_dd")',
            build_for_testing,
        )
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn('SYMROOT=$(package_symroot "$package_dd")', test_sh)
        self.assertIn('OBJROOT=$(package_objroot "$package_dd")', test_sh)
        self.assertIn(
            'SHARED_PRECOMPS_DIR=$(package_shared_precomps_dir "$package_dd")',
            test_sh,
        )

    def test_verify_prefetch_helpers_exist(self) -> None:
        text = (ROOT / "Scripts" / "verify-changed.sh").read_text(encoding="utf-8")
        self.assertIn("should_prefetch_app_during_parallel", text)
        self.assertIn("start_app_build_prefetch", text)
        self.assertIn("finish_app_build_prefetch", text)
        self.assertIn("try_reuse_warm_app_products", text)
        self.assertIn("cleanup_app_prefetch", text)
        self.assertIn("classify-play-shell-diff.py", (ROOT / "Scripts" / "change-classification.sh").read_text(encoding="utf-8"))
        self.assertIn("trinket_apply_play_shell_smoke_demotion", (ROOT / "Scripts" / "change-classification.sh").read_text(encoding="utf-8"))

    def test_run_env_removes_shared_packages_derived_data(self) -> None:
        text = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        prune = text.split("trinket_derived_data_age_prune()", 1)[1].split(
            "trinket_simulator_cleanup_idle_pool()", 1
        )[0]
        self.assertIn('Packages/.DerivedData', prune)
        self.assertIn('rm -rf "$repo_root/Packages/.DerivedData"', prune)

    def test_presentation_only_line_classifier(self) -> None:
        classifier = load_script(
            "classify_presentation_only", "classify-presentation-only.py"
        )
        self.assertTrue(
            classifier._line_is_presentation(
                "public static let mysteryRewardArtworkSize: CGFloat = 56"
            )
        )
        self.assertTrue(
            classifier._line_is_presentation('Text("PICK A REWARD")')
        )
        self.assertTrue(
            classifier._line_is_presentation('systemIcon: "gift.fill",')
        )
        self.assertFalse(
            classifier._line_is_presentation(
                "accessibilityIdentifier: AccessibilityID.Mystery.confirmChoiceButton"
            )
        )
        self.assertFalse(
            classifier._line_is_presentation("private func baseItemPreview(")
        )
        self.assertFalse(
            classifier._line_is_presentation("playerSave.homestead.effects.adjustedGold(amount)")
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
