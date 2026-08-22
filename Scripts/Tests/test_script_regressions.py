#!/usr/bin/env python3
"""Focused regressions for script safety checks."""

from __future__ import annotations

import importlib.util
import json
import os
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
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("restore-and-build", workflow)
        self.assertNotIn("actions/cache/restore@", workflow)

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


    def test_run_env_removes_shared_packages_derived_data(self) -> None:
        text = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        prune = text.split("trinket_derived_data_age_prune()", 1)[1].split(
            "trinket_simulator_cleanup_idle_pool()", 1
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
