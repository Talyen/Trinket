#!/usr/bin/env python3
"""Focused regressions for script safety checks."""

from __future__ import annotations

import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import time
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
        cls.check_docs = load_script("check_docs", "check-docs.py")

    def make_sfx_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "SoundManifest",
            "Raw Assets/Sound Effects",
            "Trinket/Media/SFX",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        for relative in ("Scripts/prepare-sfx-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)

        source = root / "Raw Assets/Sound Effects/clip.wav"
        source.write_bytes(b"fixture audio")
        (root / "SoundManifest/sfx.tsv").write_text(
            "# id\tswift_symbol\tasset_name\tsource_path\tvolume_gain\n"
            "test_clip\ttestClip\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
            encoding="utf-8",
        )

        conversion_log = root / "afconvert.log"
        afconvert = root / "bin/afconvert"
        afconvert.write_text(
            "#!/usr/bin/env bash\n"
            "printf 'convert\\n' >> \"$AFCONVERT_LOG\"\n"
            "cp \"$1\" \"$2\"\n",
            encoding="utf-8",
        )
        afconvert.chmod(0o755)
        environment = {
            **os.environ,
            "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
            "AFCONVERT_LOG": str(conversion_log),
        }
        return root, environment, conversion_log

    def run_sfx_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(root / "Scripts/prepare-sfx-assets.sh")],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_sfx_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_sfx_fixture(directory)

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_sfx_fixture(root, {**environment, **overrides})
                self.assertEqual(result.returncode, 0, result.stderr)
                conversion_count = conversion_log.read_text(encoding="utf-8").count("convert")
                self.assertEqual(conversion_count, expected_conversions)

            assert_run(1)
            generated = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift"
            ).read_text(encoding="utf-8")
            self.assertIn('public static let testClip = "test_clip"', generated)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXSourceHashes.generated.tsv"
            )
            with state.open("a", encoding="utf-8") as handle:
                handle.write("orphan\tstale\tstale-profile\n")

            assert_run(1)
            self.assertNotIn("orphan", state.read_text(encoding="utf-8"))

            assert_run(2, SFX_AAC_BITRATE="96000")

            state.unlink()
            assert_run(3)

            output = root / "Trinket/Media/SFX/sfx_test_clip.m4a"
            output.unlink()
            assert_run(4)

            assert_run(5, FORCE_ASSET_REENCODE="1")

    def test_sfx_manifest_rejects_invalid_and_duplicate_swift_symbols(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_sfx_fixture(directory)
            manifest = root / "SoundManifest/sfx.tsv"
            for reserved in ("repeat", "actor", "async", "package"):
                manifest.write_text(
                    f"test_clip\t{reserved}\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                    encoding="utf-8",
                )
                invalid = self.run_sfx_fixture(root, environment)
                self.assertNotEqual(invalid.returncode, 0, reserved)
                self.assertIn("reserved Swift keyword", invalid.stderr, reserved)

            manifest.write_text(
                "first\tsharedSymbol\tsfx_first\tRaw Assets/Sound Effects/clip.wav\t1.0\n"
                "second\tsharedSymbol\tsfx_second\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                encoding="utf-8",
            )
            duplicate = self.run_sfx_fixture(root, environment)
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn("Duplicate SFX Swift symbol 'sharedSymbol'", duplicate.stderr)

    def make_music_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "MusicManifest",
            "Raw Assets/Music",
            "Trinket/Media/Music",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        for relative in ("Scripts/prepare-music-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)

        source = root / "Raw Assets/Music/track.mp3"
        source.write_bytes(b"fixture music")
        (root / "MusicManifest/music.tsv").write_text(
            "# kind\tid\tasset_name\tsource_path\tboss_enemy_id\tlooping\tvolume_gain\n"
            "menu\ttest_track\tmusic_test_track\tRaw Assets/Music/track.mp3\tnone\ttrue\t1.0\n",
            encoding="utf-8",
        )

        conversion_log = root / "afconvert.log"
        afconvert = root / "bin/afconvert"
        afconvert.write_text(
            "#!/usr/bin/env bash\n"
            "printf 'convert\\n' >> \"$AFCONVERT_LOG\"\n"
            "cp \"$1\" \"$2\"\n",
            encoding="utf-8",
        )
        afconvert.chmod(0o755)
        environment = {
            **os.environ,
            "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
            "AFCONVERT_LOG": str(conversion_log),
        }
        return root, environment, conversion_log

    def run_music_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "Scripts/prepare-music-assets.sh"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_music_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_music_fixture(directory)

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_music_fixture(root, {**environment, **overrides})
                self.assertEqual(result.returncode, 0, result.stderr)
                conversion_count = conversion_log.read_text(encoding="utf-8").count("convert")
                self.assertEqual(conversion_count, expected_conversions)

            assert_run(1)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/MusicSourceHashes.generated.tsv"
            )
            with state.open("a", encoding="utf-8") as handle:
                handle.write("orphan\tstale\tstale-profile\n")

            assert_run(1)
            self.assertNotIn("orphan", state.read_text(encoding="utf-8"))
            assert_run(2, MUSIC_AAC_BITRATE="128000")
            assert_run(3, FORCE_ASSET_REENCODE="1")

    def test_assert_generated_output_supports_tiered_asset_idempotence(self) -> None:
        text = (ROOT / "Scripts" / "assert-generated-output.sh").read_text(encoding="utf-8")
        self.assertIn("snapshot_tracked_asset_catalogs", text)
        self.assertIn("snapshot_for_idempotent_check", text)
        self.assertIn("--strict-assets", text)

    def test_media_orphan_pruning_is_extension_scoped(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resources = root / "Media"
            resources.mkdir()
            active = root / "active.txt"
            active.write_text("keep.mp4\n", encoding="utf-8")
            for name in ("keep.mp4", "remove.mp4", "ignore.m4a"):
                (resources / name).write_text(name, encoding="utf-8")

            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; trinket_asset_prune_orphans "$2" "$3" cinematic mp4',
                    "media-prune-test",
                    str(ROOT / "Scripts/lib/media-assets.sh"),
                    str(resources),
                    str(active),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((resources / "keep.mp4").exists())
            self.assertFalse((resources / "remove.mp4").exists())
            self.assertTrue((resources / "ignore.m4a").exists())

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

    def test_triggers_swift_maps_known_token_to_grouped_field(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("on_cleanse_self_heal:2"),
            "CombatTraitTriggers(healing: HealingTriggers(cleanseSelfHeal: 2))",
        )

    def test_triggers_swift_rename_table_tokens(self) -> None:
        output = self.codegen.triggers_swift("on_cleanse_draw:1|on_gain_gold_heal:3")
        self.assertIn("cleanseBonusDraw: 1", output)
        self.assertIn("gainGoldBonusHealSelf: 3", output)

    def test_triggers_swift_damage_below_health_percent_both_arities(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("damage_below_health_percent:50:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentBonus: 5))",
        )
        self.assertEqual(
            self.codegen.triggers_swift("damage_below_health_percent:50:fire:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentKeyword: .fire, "
            "damageBelowHealthPercentBonus: 5))",
        )

    def test_triggers_swift_generic_path_converts_snake_case_field(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("poison_decay_slow_percent:50"),
            "CombatTraitTriggers(dot: DotTriggers(poisonDecaySlowPercent: 50))",
        )

    def test_triggers_swift_unknown_token_fails_loudly(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.triggers_swift("not_a_real_trigger:1")

    def test_triggers_swift_rejects_glued_tokens(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.triggers_swift("poison_decay_slow_percent:50,bogus_field:1")

    def test_modifier_token_to_swift_multipart_keyword(self) -> None:
        self.assertEqual(
            self.codegen.modifier_token_to_swift("damage_dealt:fire:3"),
            ".damageDealt(.fire, 3)",
        )

    def test_plan_metadata_requires_lifecycle_fields_and_blocked_reason(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            valid = root / "valid.md"
            valid.write_text(
                "---\n"
                "type: execution-plan\n"
                "status: active\n"
                "created: 2026-08-20\n"
                "updated: 2026-08-20\n"
                "expires: 2026-09-03\n"
                "---\n\n# Plan\n",
                encoding="utf-8",
            )
            metadata, errors = self.check_docs.plan_metadata(valid)
            self.assertEqual(errors, [])
            self.assertEqual(metadata["status"], "active")

            blocked = root / "blocked.md"
            blocked.write_text(valid.read_text(encoding="utf-8").replace("status: active", "status: blocked"), encoding="utf-8")
            _, errors = self.check_docs.plan_metadata(blocked)
            self.assertIn("blocked plans require reason", errors)

    def test_completed_plans_are_archived_instead_of_deleted(self) -> None:
        plan_name = f"ArchiveFixture{os.getpid()}"
        active_path = ROOT / "Docs" / "Plans" / f"{plan_name}.md"
        archived_path = ROOT / "Docs" / "Plans" / "Archived" / f"{plan_name}.md"
        plan = (
            "---\n"
            "type: execution-plan\n"
            "status: complete\n"
            "created: 2026-08-01\n"
            "updated: 2026-08-20\n"
            "expires: 2026-08-19\n"
            "---\n\n# Archived fixture\n"
        )
        try:
            active_path.write_text(plan, encoding="utf-8")
            rejected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-docs.py")],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("must be moved to Docs/Plans/Archived/", rejected.stderr)

            active_path.unlink()
            archived_path.write_text(plan, encoding="utf-8")
            accepted = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-docs.py")],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stderr)
        finally:
            active_path.unlink(missing_ok=True)
            archived_path.unlink(missing_ok=True)

    def test_markdown_inventory_excludes_ignored_run_reports(self) -> None:
        paths = self.check_docs.markdown_files()
        self.assertTrue(paths)
        self.assertTrue(all(path.suffix == ".md" for path in paths))
        self.assertFalse(any("BalanceSweepReports" in path.parts for path in paths))

    def test_ui_style_requires_explicit_catalog_artwork_display_size(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ArtworkFixture.swift"
            fixture.write_text(
                "Image.preparedAsset(named: art.imageName)\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(
                [str(ROOT / "Scripts" / "check-ui-style.sh"), str(fixture)],
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
                [str(ROOT / "Scripts" / "check-ui-style.sh"), str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout + accepted.stderr)

    def test_agent_invariants_cover_entropy_sleep_persistence_and_concurrency(self) -> None:
        text = (ROOT / "Scripts" / "check-agent-invariants.sh").read_text(encoding="utf-8")
        self.assertIn(r"\b(Date|UUID)\(\)", text)
        self.assertIn("Task.sleep", text)
        self.assertIn("PersistenceCheck", text)
        self.assertIn("@unchecked Sendable", text)
        self.assertIn("ArtworkWorkingSetCheck", text)
        self.assertIn("Trinket/App/TrinketApp.swift", text)

    def test_accessibility_ids_reject_duplicate_constants_and_raw_uitest_literals(self) -> None:
        checker = load_script("check_accessibility_ids", "check-accessibility-ids.py")
        duplicates = checker.unique_constants()
        self.assertEqual(duplicates, [])
        raw = checker.raw_uitest_literals(checker.allowlist())
        self.assertEqual(raw, [], raw)

    def test_style_gate_invokes_agent_invariants_and_accessibility_ids(self) -> None:
        text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn("check-agent-invariants.sh", text)
        self.assertIn("check-accessibility-ids.sh", text)

    def test_lint_analyze_is_ci_only(self) -> None:
        text = (ROOT / "Scripts" / "lint-analyze.sh").read_text(encoding="utf-8")
        self.assertIn("swiftlint analyze", text)
        self.assertIn("compiler-log-path", text)
        # Advisory analyze must not emit Checks annotations: that reporter
        # volume plus cache save overflowed the 30-minute build job timeout.
        self.assertNotIn("--reporter github-actions-logging", text)
        self.assertIn("build-app-", text)
        style = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertNotIn("lint-analyze.sh", style)
        handoff = (ROOT / "Scripts" / "handoff.sh").read_text(encoding="utf-8")
        self.assertNotIn("lint-analyze.sh", handoff)
        restore = (ROOT / ".github" / "actions" / "restore-and-build" / "action.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("lint-analyze.sh", restore)
        tests_yml = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        self.assertIn("lint-analyze.sh", tests_yml)
        self.assertRegex(
            tests_yml,
            r"name: Advisory SwiftLint analyze\n(?:.*\n){0,8}    continue-on-error: true",
        )
        self.assertRegex(
            tests_yml,
            r"SwiftLint analyze\n(?:.*\n){0,6}        continue-on-error: true",
        )
        self.assertRegex(
            tests_yml,
            r"name: Build for testing\n    needs: \[changes\]\n",
        )
        self.assertNotIn("needs: [changes, gate]", tests_yml)
        self.assertRegex(
            tests_yml,
            r"name: Build for testing\n(?:.*\n){0,8}    timeout-minutes: 30",
        )

    def test_ci_analyze_is_advisory(self) -> None:
        text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"analyze:\n(?:.*\n){0,8}    continue-on-error: true")
        self.assertNotRegex(text, r"ci-ok:\n(?:.*\n)*?needs:.*analyze")

    def test_change_budget_warns_when_package_production_lacks_tests(self) -> None:
        text = (ROOT / "Scripts" / "change-budget.sh").read_text(encoding="utf-8")
        self.assertIn("--base", text)
        self.assertIn(
            "production Swift in ${package} changed with no test path in that package",
            text,
        )

    def test_ci_diff_review_is_advisory(self) -> None:
        text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"diff-review:\n(?:.*\n){0,8}    continue-on-error: true")
        self.assertNotRegex(text, r"ci-ok:\n(?:.*\n)*?needs:.*diff-review")

    def test_prepare_asset_scripts_use_c_locale_header_preserving_sort(self) -> None:
        scripts = tuple(
            path.name
            for path in sorted((ROOT / "Scripts").glob("prepare-*.sh"))
        )
        for name in scripts:
            text = (ROOT / "Scripts" / name).read_text(encoding="utf-8")
            sort_owner = (
                (ROOT / "Scripts" / "lib" / "media-assets.sh").read_text(encoding="utf-8")
                if "source \"Scripts/lib/media-assets.sh\"" in text
                else text
            )
            self.assertTrue(
                "LC_ALL=C sort" in sort_owner,
                name,
            )
            self.assertTrue(
                ("head -n 2" in sort_owner and "tail -n +3" in sort_owner)
                or ("grep -v '^#'" in sort_owner and "# asset_name" in sort_owner),
                f"{name} should preserve hash TSV headers before sorting",
            )
            self.assertIn("cmp -s", sort_owner, f"{name} should skip rewriting unchanged hash/catalog stamps")

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
        owner = (ROOT / "Scripts" / "swift-source-dirs.env").read_text(encoding="utf-8")
        for plan in (
            "Smoke.xctestplan",
            "FullUI.xctestplan",
            "BattlePerformance.xctestplan",
        ):
            self.assertIn(plan, owner)
        self.assertIn('build_input_paths=("${TRINKET_BUILD_ROOTS[@]}" "${TRINKET_PROJECT_INPUTS[@]}")', text)
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
        self.assertIn("default: './Scripts/build-for-testing.sh'", text)
        self.assertNotIn("default: './Scripts/build-for-testing.sh --app-only'", text)
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("restore-and-build", workflow)
        self.assertTrue(
            "./Scripts/test.sh unit" in workflow or "./Scripts/test-package.sh" in workflow,
            "unit job must invoke package tests via test.sh or test-package.sh",
        )
        self.assertNotIn("./Scripts/test.sh unit --no-build", workflow)
        self.assertIn("build-for-testing.sh --app-only", workflow)
        self.assertIn("name: Homestead", workflow)
        self.assertIn("preboot-simulator: 'true'", workflow)
        self.assertIn("skip-build: 'true'", workflow)
        self.assertIn("sparse-checkout-cone-mode: true", workflow)
        self.assertIn("test -f project.yml", workflow)
        self.assertNotIn("checkout-ci", workflow)
        self.assertIn("Smoke tests (${{ matrix.name }})", workflow)
        self.assertIn("needs.changes.outputs.infra", workflow)
        self.assertNotIn("actions/cache/restore@", workflow)
        self.assertIn("stage-ci-test-artifact.sh", text)
        self.assertIn("skip-build", text)
        cache_key = (
            ROOT / ".github" / "actions" / "build-cache-key" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('git rev-parse "HEAD:Raw Assets"', cache_key)
        sparse_block = workflow.split("sparse-checkout:", 1)[1]
        self.assertIn(".github", sparse_block)
        self.assertNotIn("Raw Assets", sparse_block)

    def test_ci_gate_fast_skips_generation_and_style(self) -> None:
        text = (ROOT / "Scripts" / "ci-gate.sh").read_text(encoding="utf-8")
        self.assertIn("--fast", text)
        self.assertIn("check-module-boundaries.sh", text)
        self.assertIn("check-swift-testing-migration.sh", text)
        self.assertIn("release-notes.sh validate", text)
        self.assertIn("=== Fast gate checks passed ===", text)

    def test_test_scripts_supports_skip_docs(self) -> None:
        text = (ROOT / "Scripts" / "test-scripts.sh").read_text(encoding="utf-8")
        self.assertIn("--skip-docs", text)
        self.assertIn('if [[ "$SKIP_DOCS" != true ]]; then', text)

    def test_handoff_runs_cheap_ci_slices_and_skips_docs_on_final(self) -> None:
        handoff = (ROOT / "Scripts" / "handoff.sh").read_text(encoding="utf-8")
        self.assertIn("run_cheap_ci_slices", handoff)
        self.assertIn("check-module-boundaries.sh", handoff)
        self.assertIn("check-swift-testing-migration.sh", handoff)
        self.assertIn("release-notes.sh validate", handoff)
        self.assertIn('if [[ "$FINAL" == true ]]; then', handoff)
        self.assertIn("./Scripts/test-scripts.sh --skip-docs", handoff)
        self.assertIn('kind" == docs && "$FINAL" == true', handoff)

    def test_docs_markdown_routes_check_docs(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Docs/Platform/Verification.md",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        self.assertEqual(plan, ["python3 ./Scripts/check-docs.py"])

    def test_agent_push_gate_skips_generate_when_classification_does_not_need_it(self) -> None:
        text = (ROOT / "Scripts" / "agent-push-gate.sh").read_text(encoding="utf-8")
        self.assertIn("TRINKET_NEEDS_CONTENT_GENERATION", text)
        self.assertIn("TRINKET_NEEDS_PROJECT_GENERATION", text)
        self.assertIn("skip generate (no content, project, or asset inputs)", text)

    def test_pre_push_path_scopes_style_to_pushed_swift(self) -> None:
        text = (ROOT / ".githooks" / "pre-push").read_text(encoding="utf-8")
        self.assertIn('test.sh style "${style_swift[@]}"', text)
        self.assertIn("check-platform-api-bans.sh", text)
        self.assertIn("check-agent-invariants.sh", text)
        self.assertIn("test-package.sh", text)
        self.assertLess(text.find("agent-push-gate.sh"), text.find("test-package.sh"))
        self.assertIn('"$remote_sha..$local_sha"', text)
        self.assertIn("push_lines+=", text)
        self.assertNotIn("./Scripts/test.sh style\n", text)

    def test_content_codegen_routes_generation_and_script_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/content_codegen.py",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/generate.sh", plan)
        self.assertIn("./Scripts/test-scripts.sh", plan)

    def test_media_assets_lib_routes_asset_generation(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/lib/media-assets.sh",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/generate.sh --assets", plan)
        self.assertIn("./Scripts/test-scripts.sh", plan)

    def test_authored_content_swift_routes_generation_style_and_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
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

    def test_build_script_routes_script_gate(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/build.sh",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("./Scripts/test-scripts.sh", result.stdout)

    def test_ci_diagnostics_stages_structured_artifacts_and_failure_forensics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            raw = results / "raw"
            raw.mkdir(exist_ok=True)
            (raw / "pass.log").write_text("pass\n", encoding="utf-8")
            (results / "pass.xcresult").mkdir()
            (results / "pass-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(results / "pass.xcresult"),
                    }
                ),
                encoding="utf-8",
            )
            (results / "ci-diagnostics.json").write_text(
                json.dumps({"category": "passed"}), encoding="utf-8"
            )
            passed_stage = Path(directory) / "passed-artifact"
            staged = subprocess.run(
                [
                    str(ROOT / "Scripts" / "ci-diagnostics.sh"),
                    "--stage-artifacts",
                    str(results),
                    str(passed_stage),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            self.assertFalse((passed_stage / "raw").exists())
            self.assertTrue((passed_stage / "ci-diagnostics.json").exists())

            raw.mkdir(exist_ok=True)
            (raw / "pass.log").write_text("failure evidence\n", encoding="utf-8")
            (results / "pass.xcresult").mkdir(exist_ok=True)
            (results / "ci-diagnostics.json").write_text(
                json.dumps({"category": "test-failure"}), encoding="utf-8"
            )
            failed_stage = Path(directory) / "failed-artifact"
            staged = subprocess.run(
                [
                    str(ROOT / "Scripts" / "ci-diagnostics.sh"),
                    "--stage-artifacts",
                    str(results),
                    str(failed_stage),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            self.assertTrue((failed_stage / "raw" / "pass.log").exists())

    def test_ci_diagnostics_selects_session_and_cleans_passed_history(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, status, exit_code in (
                ("old", "session-old", "passed", 0),
                ("current", "session-current", "failed", 65),
            ):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": status,
                            "exit_code": exit_code,
                            "result_bundle": str(results / f"{label}.xcresult"),
                            "generated_at": f"2026-08-20T00:00:0{len(label)}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            selected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env={**os.environ, "TRINKET_DIAGNOSTICS_SESSION_ID": "session-current"},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(selected.returncode, 0, selected.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["recorded_invocations"], 1)
            self.assertEqual(payload["session_id"], "session-current")

            passed_bundle = results / "passed.xcresult"
            passed_bundle.mkdir()
            raw = results / "raw"
            raw.mkdir()
            (raw / "passed.log").write_text("pass\n", encoding="utf-8")
            (results / "passed-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(passed_bundle),
                    }
                ),
                encoding="utf-8",
            )
            cleaned = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cleaned.returncode, 0, cleaned.stderr)
            self.assertFalse(passed_bundle.exists())
            self.assertFalse((raw / "passed.log").exists())
            self.assertTrue((results / "current-invocation.json").exists())

            kept_bundle = results / "kept.xcresult"
            kept_bundle.mkdir()
            (results / "kept-invocation.json").write_text(
                json.dumps(
                    {
                        "status": "passed",
                        "exit_code": 0,
                        "result_bundle": str(kept_bundle),
                    }
                ),
                encoding="utf-8",
            )
            kept = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", "--keep", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(kept.returncode, 0, kept.stderr)
            self.assertTrue(kept_bundle.exists())

    def test_ci_diagnostics_warns_when_sessions_share_a_results_dir(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, seconds in (("older", "session-a", "00"), ("newer", "session-b", "30")):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": "passed",
                            "exit_code": 0,
                            "result_bundle": "",
                            "generated_at": f"2026-08-20T00:00:{seconds}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            unscoped = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(unscoped.returncode, 0, unscoped.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["distinct_sessions"], 2)
            self.assertIn("Warning:", payload["detail"])
            self.assertIn("--reset", payload["session_warning"])

    def test_cleanup_sweeps_orphan_bundles_and_logs_by_age(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            raw = results / "raw"
            raw.mkdir(parents=True)
            stale_time = time.time() - 10 * 86400

            orphan_bundle = results / "crashed-run.xcresult"
            orphan_bundle.mkdir()
            orphan_log = raw / "crashed-run.log"
            orphan_log.write_text("partial output\n", encoding="utf-8")
            fresh_log = raw / "fresh-run.log"
            fresh_log.write_text("recent\n", encoding="utf-8")
            claimed_log = raw / "claimed-run.log"
            claimed_log.write_text("has diagnostics report\n", encoding="utf-8")
            (results / "claimed-run-diagnostics.json").write_text("{}", encoding="utf-8")
            # A retained failure keeps invocation manifests present so cleanup
            # does not remove raw/ wholesale — the mixed-state case the sweep
            # is written for.
            (results / "failed-invocation.json").write_text(
                json.dumps({"status": "failed", "exit_code": 65, "result_bundle": ""}),
                encoding="utf-8",
            )
            for path in (orphan_bundle, orphan_log):
                os.utime(path, (stale_time, stale_time))

            cleaned = subprocess.run(
                [str(ROOT / "Scripts" / "ci-diagnostics.sh"), "--cleanup", str(results)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cleaned.returncode, 0, cleaned.stderr)
            self.assertFalse(orphan_bundle.exists())
            self.assertFalse(orphan_log.exists())
            # Fresh orphans and evidence with a diagnostics report survive.
            self.assertTrue(fresh_log.exists())
            self.assertTrue(claimed_log.exists())

    def test_artifact_consumers_defer_run_env_cleanup(self) -> None:
        performance = (ROOT / "Scripts" / "performance.sh").read_text(encoding="utf-8")
        self.assertIn(
            'TRINKET_CLEANUP_TEST_ARTIFACTS=0 \\\nRESULTS_DIR="$OUTPUT_DIR/TestResults"',
            performance,
        )

        test_job = (ROOT / ".github" / "actions" / "test-job" / "action.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("TRINKET_CLEANUP_TEST_ARTIFACTS: 0", test_job)

    def test_record_time_profiler_avoids_simulator_device_deadlock(self) -> None:
        script = ROOT / "Scripts" / "record-time-profiler.sh"

        def printed(*args: str) -> str:
            result = subprocess.run(
                [str(script), "--print-command", *args],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

        default = printed("--output", "/tmp/trinket-tp.trace", "--time-limit", "8s")
        self.assertIn("--instrument", default)
        self.assertIn("Time Profiler", default)
        self.assertIn("--attach", default)
        self.assertIn("Trinket", default)
        self.assertNotIn("--all-processes", default)
        self.assertNotIn("--device", default)
        self.assertNotIn("--template", default)

        wide = printed("--output", "/tmp/trinket-tp.trace", "--all-processes")
        self.assertIn("--all-processes", wide)
        self.assertNotIn("--attach", wide)
        self.assertNotIn("--device", wide)

        text = script.read_text(encoding="utf-8")
        self.assertIn("DTServiceHub", text)
        self.assertIn("ending recording", text)
        self.assertNotIn("SAVE_BUDGET", text)
        self.assertIn("kill -INT", text)

    def test_new_plan_scaffold_creates_lifecycle_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            plan_name = f"TokenEfficiencyFixture{Path(directory).name}"
            plan_path = ROOT / "Docs" / "Plans" / f"{plan_name}.md"
            try:
                created = subprocess.run(
                    [str(ROOT / "Scripts" / "new-plan.sh"), plan_name],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(created.returncode, 0, created.stderr)
                text = plan_path.read_text(encoding="utf-8")
                self.assertIn("type: execution-plan", text)
                self.assertIn("status: active", text)
                self.assertIn("expires:", text)
                self.assertIn("Docs/Plans/Archived/", text)
            finally:
                plan_path.unlink(missing_ok=True)

    def test_agent_context_shell_quotes_paths_with_spaces(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Raw Assets/Art/example.png",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(r"Raw\ Assets/Art/example.png", result.stdout)

    def test_agent_context_requires_explicit_scope(self) -> None:
        result = subprocess.run(
            [str(ROOT / "Scripts" / "agent-context.sh"), "--agent"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --paths", result.stderr)

    def test_handoff_requires_explicit_scope_and_supports_working_tree_override(self) -> None:
        missing = subprocess.run(
            [str(ROOT / "Scripts" / "handoff.sh"), "--dry-run"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("requires --paths", missing.stderr)
        explicit = subprocess.run(
            [str(ROOT / "Scripts" / "handoff.sh"), "--dry-run", "--working-tree"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(explicit.returncode, 0, explicit.stderr)

    def test_agent_context_caps_accidental_working_tree_scope(self) -> None:
        with tempfile.TemporaryDirectory(
            dir=ROOT, prefix=".agent-context-cap-"
        ) as probe_directory:
            probe = Path(probe_directory) / "untracked-probe.txt"
            probe.write_text("working-tree cap probe\n", encoding="utf-8")
            result = subprocess.run(
                [str(ROOT / "Scripts" / "agent-context.sh"), "--agent", "--working-tree"],
                cwd=ROOT,
                env={**os.environ, "TRINKET_MAX_WORKING_TREE_PATHS": "0"},
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 3)
        self.assertIn("use explicit --paths or --allow-broad-scope", result.stderr)

    def test_handoff_profiles_final_documentation_route_automatically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            profile_directory = Path(directory)
            result = subprocess.run(
                [
                    str(ROOT / "Scripts" / "handoff.sh"),
                    "--final",
                    "--keep-plan",
                    "--paths",
                    "Docs/README.md",
                ],
                cwd=ROOT,
                env={
                    **os.environ,
                    "TRINKET_OUTPUT_PROFILE_DIR": str(profile_directory),
                },
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            profile_files = [path for path in profile_directory.rglob("*") if path.is_file()]
            self.assertTrue(profile_files, "automatic profiling did not write metadata")
            profile_text = "\n".join(
                path.read_text(encoding="utf-8") for path in profile_files
            )
            self.assertIn("documentation", profile_text)
            self.assertNotIn("check-docs.py", profile_text)

    def test_handoff_profiling_can_be_bypassed_for_debugging(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            profile_directory = Path(directory)
            result = subprocess.run(
                [
                    str(ROOT / "Scripts" / "handoff.sh"),
                    "--final",
                    "--keep-plan",
                    "--paths",
                    "Docs/README.md",
                ],
                cwd=ROOT,
                env={
                    **os.environ,
                    "TRINKET_OUTPUT_PROFILE": "0",
                    "TRINKET_OUTPUT_PROFILE_DIR": str(profile_directory),
                },
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(
                any(path.is_file() for path in profile_directory.rglob("*")),
                "profiling bypass unexpectedly wrote metadata",
            )

    def test_agent_context_routes_app_state_to_battle_card(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketAppState/Sources/TrinketAppState/Play/PlayBattleLaunch.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-runtime.md", result.stdout)
        self.assertIn("lookup only", result.stdout)

    def test_agent_context_routes_battle_state_to_focused_card_without_design_skill(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/BattleFeedbackLane.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-runtime.md", result.stdout)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_agent_context_routes_engine_to_engine_card(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/BattleEngine/Sources/BattleEngine/BattleState.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/battle-engine.md", result.stdout)

    def test_agent_context_routes_design_system_to_apple_design(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Modifiers.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/Skills/apple-design/SKILL.md", result.stdout)
        self.assertNotIn("Docs/AgentContext/swiftui-features.md", result.stdout)

    def test_agent_context_routes_prepared_artwork_to_swiftui_features(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/swiftui-features.md", result.stdout)

    def test_agent_context_keeps_design_skill_off_design_system_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketDesignSystem/Tests/TrinketDesignSystemTests/DesignSystemTests.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_agent_context_routes_audio_without_battle_context(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "Packages/TrinketAppState/Sources/TrinketAppState/Audio/MusicPlayer.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Docs/AgentContext/audio.md", result.stdout)
        self.assertNotIn("Docs/AgentContext/battle", result.stdout)

    def test_agent_context_routes_each_semantic_owner_to_one_required_card(self) -> None:
        cases = (
            (
                "Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift",
                "Docs/AgentContext/persistence.md",
            ),
            (
                "ContentManifest/abilities.tsv",
                "Docs/AgentContext/content-and-manifests.md",
            ),
            (
                "Scripts/check-docs.py",
                "Docs/AgentContext/ci-and-project-generation.md",
            ),
        )
        for path, expected_card in cases:
            with self.subTest(path=path):
                result = subprocess.run(
                    [
                        str(ROOT / "Scripts" / "agent-context.sh"),
                        "--agent",
                        "--paths",
                        path,
                    ],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected_card, result.stdout)
                for _, other_card in cases:
                    if other_card != expected_card:
                        self.assertNotIn(other_card, result.stdout)
                self.assertNotIn("Route metadata", result.stdout)

    def test_agent_context_does_not_attach_design_skill_to_ui_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "agent-context.sh"),
                "--agent",
                "--paths",
                "TrinketUITests/Smoke/SmokeShellTests.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("apple-design/SKILL.md", result.stdout)

    def test_mystery_subflow_runs_play_smoke(self) -> None:
        # Deterministic routing: any Play diff runs SmokeShellTests; no demotion
        # to compile-only for subflow-only diffs.
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
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
        self.assertIn("SmokeShellTests", result.stdout)

    def test_play_shell_keeps_smoke_shell(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
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
        # No lab demotion: a DEBUG variant file still runs the full package
        # suite plus the SmokeBattleTests canary.
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
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
        self.assertIn("./Scripts/test-package.sh TrinketBattleFeature", plan)
        self.assertNotIn("--build-only", plan)
        self.assertIn("SmokeBattleTests", plan)

    def test_battle_feature_shipping_keeps_package_tests_and_smoke(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
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
                str(ROOT / "Scripts" / "handoff.sh"),
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

    def test_compile_only_packages_are_disjoint_from_test_packages(self) -> None:
        owner = (ROOT / "Scripts" / "swift-source-dirs.env").read_text(encoding="utf-8")
        test_packages = re.findall(
            r"^\s+(Trinket\w+|BattleEngine)\s*$",
            owner.split("TRINKET_TEST_PACKAGES=(")[1].split(")")[0],
            re.MULTILINE,
        )
        compile_only = re.findall(
            r"^\s+(Trinket\w+|BattleEngine)\s*$",
            owner.split("TRINKET_COMPILE_ONLY_PACKAGES=(")[1].split(")")[0],
            re.MULTILINE,
        )
        self.assertEqual(set(test_packages) & set(compile_only), set())
        classified = re.search(
            r"case \"\$package\" in\n\s+([^\n]+)",
            (ROOT / "Scripts" / "change-classification.sh").read_text(encoding="utf-8"),
        )
        self.assertIsNotNone(classified)
        for package in classified.group(1).split("|"):  # type: ignore[union-attr]
            package = package.strip().rstrip(")")
            self.assertTrue(
                package in test_packages or package in compile_only,
                f"{package} missing from swift-source-dirs package registry",
            )

    def test_battle_runtime_routes_to_app_build_not_test_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Packages/BattleEngine/Sources/BattleEngine/BattleRuntime.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("test-package.sh BattleEngine", plan)

    def test_test_support_routes_to_app_build_not_test_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Packages/TrinketTestSupport/Sources/TrinketTestSupport/CombatantFixtures.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/build.sh", plan)
        self.assertNotIn("test-package.sh TrinketTestSupport", plan)

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
        self.assertIn('--run "$invocation_id"', text)
        self.assertIn("--xcresult", text)
        test_text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn('--run "$XCODE_RUNNER_INVOCATION_ID"', test_text)

    def test_test_package_parallelizes_multiple_packages(self) -> None:
        # test-package.sh is the single owner of parallel package builds/tests:
        # per-package DerivedData tenants with SYMROOT/OBJROOT pins.
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
        # build-for-testing.sh and test.sh delegate package work to the single
        # parallel owner instead of re-implementing the xargs/tenant protocol.
        build_for_testing = (ROOT / "Scripts" / "build-for-testing.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("test-package.sh --build-for-testing", build_for_testing)
        self.assertIn("TRINKET_BUILD_FINGERPRINTS_APP", build_for_testing)
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn("test-package.sh --build-for-testing", test_sh)
        self.assertIn("test-package.sh --no-build", test_sh)

    def test_bare_full_ui_requires_explicit_opt_in(self) -> None:
        # Full exhaustive UI is CI-owned post-push; bare local runs must opt in.
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn('TRINKET_ALLOW_FULL_UI:-', test_sh)
        self.assertIn('GITHUB_ACTIONS:-}', test_sh)
        self.assertIn("Refusing a bare local full exhaustive UI run", test_sh)
        deploy = (ROOT / "Scripts" / "test-deploy.sh").read_text(encoding="utf-8")
        # Release-time deploy verification is the sanctioned bypass.
        self.assertIn("TRINKET_ALLOW_FULL_UI=1 ./Scripts/test.sh ui", deploy)


    def test_run_env_removes_shared_packages_derived_data(self) -> None:
        text = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        prune = text.split("trinket_derived_data_age_prune()", 1)[1].split(
            "trinket_simulator_enforce_single_warm_booted()", 1
        )[0]
        self.assertIn('Packages/.DerivedData', prune)
        self.assertIn('rm -rf "$repo_root/Packages/.DerivedData"', prune)


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
            "trinket_bind_agent_slot", 1
        )[0]
        self.assertIn("trinket_run_env_self_clean_hygiene", install)
        self.assertNotIn("trinket_run_env_install_test_simulator_cleanup", text)
        release = text.split("trinket_run_env_release_slots()", 1)[1].split(
            "trinket_run_env_install_release_trap", 1
        )[0]
        self.assertIn("TRINKET_SELF_CLEAN_OWNER", release)
        self.assertIn("trinket_run_env_self_clean_hygiene", release)
        single = text.split("trinket_simulator_enforce_single_warm_booted()", 1)[1].split(
            "trinket_run_env_cleanup_test_artifacts", 1
        )[0]
        self.assertIn('TRINKET_CLEANUP_SINGLE_WARMED:-1', single)
        self.assertIn("trinket_simulator_is_shared_name", single)
        self.assertIn("trinket_simulator_is_active_agent_name", single)
        self.assertIn("trinket_simulator_is_shared_name", text)
        self.assertIn("Trinket CI", text)
        self.assertIn("trinket_simulator_is_managed_name", text)
        self.assertNotIn("TRINKET_CLEANUP_IDLE_POOL", text)
        self.assertNotIn("TRINKET_CLEANUP_EXCESS_SIMULATORS", text)
        self.assertNotIn("TRINKET_KEEP_DIAGNOSTICS", text)
        self.assertNotIn("TRINKET_SIM_SLOT_SKIP_ACQUIRE", text)
        self.assertNotIn("TRINKET_ARTIFACT_MAX_AGE_DAYS", text)
        self.assertIn('TRINKET_MAX_AGENT_SIMS:-1', text)
        self.assertFalse((ROOT / "Scripts" / "clean-dev-artifacts.sh").exists())


if __name__ == "__main__":
    unittest.main()
