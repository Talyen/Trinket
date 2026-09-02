#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class CIVerificationScriptTests(ScriptRegressionTestCase):
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
        self.assertIn("=== Fast gate checks passed ===", text)
        self.assertIn("cheap-slices", text)
        cheap = (ROOT / "Scripts" / "config" / "cheap-slices.txt").read_text(encoding="utf-8")
        self.assertIn("check-module-boundaries.sh", cheap)
        self.assertIn("check-swift-testing-migration.sh", cheap)
        self.assertIn("release-notes.sh validate", cheap)

    def test_test_scripts_supports_skip_docs(self) -> None:
        text = (ROOT / "Scripts" / "test-scripts.sh").read_text(encoding="utf-8")
        self.assertIn("--skip-docs", text)
        self.assertIn('if [[ "$SKIP_DOCS" != true ]]; then', text)

    def test_handoff_runs_cheap_ci_slices_and_skips_docs_on_final(self) -> None:
        handoff = (ROOT / "Scripts" / "handoff.sh").read_text(encoding="utf-8")
        self.assertIn("run_cheap_ci_slices", handoff)
        self.assertIn("source Scripts/lib/cheap-slices.sh", handoff)
        self.assertIn("trinket_run_cheap_slices", handoff)
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
        self.assertIn("python3 ./Scripts/check-docs.py", plan)
        self.assertIn("./Scripts/check-module-boundaries.sh", plan)
        self.assertIn("./Scripts/check-artwork-budget.sh", plan)

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
                self.assertIn("Docs/Plans/Archived/README.md", text)
                self.assertIn("delete this plan", text)
            finally:
                plan_path.unlink(missing_ok=True)

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
        helpers = (ROOT / "Scripts" / "lib" / "test-helpers.sh").read_text(encoding="utf-8")
        test_text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        combined = helpers + test_text
        self.assertIn('--run "$XCODE_RUNNER_INVOCATION_ID"', combined)

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
        helpers = (ROOT / "Scripts" / "lib" / "test-helpers.sh").read_text(encoding="utf-8")
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        combined = helpers + test_sh
        self.assertIn("test-package.sh --build-for-testing", combined)
        self.assertIn("test-package.sh --no-build", combined)

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
        text = (ROOT / "Scripts" / "lib" / "derived-data.sh").read_text(encoding="utf-8")
        self.assertIn('Packages/.DerivedData', text)
        self.assertIn('rm -rf "$repo_root/Packages/.DerivedData"', text)

    def test_prune_gates_bulk_wipe(self) -> None:
        text = (ROOT / "Scripts" / "prune-derived-data-cache.sh").read_text(encoding="utf-8")
        self.assertIn('CI_MODE=true', text)
        self.assertIn("--ci", text)
        self.assertIn("Skipping Intermediate/compilation-cache wipe", text)

    def test_run_env_self_cleans_on_start_and_release(self) -> None:
        text = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        simctl = (ROOT / "Scripts" / "lib" / "simctl.sh").read_text(encoding="utf-8")
        derived = (ROOT / "Scripts" / "lib" / "derived-data.sh").read_text(encoding="utf-8")
        combined = text + simctl + derived
        self.assertIn("trinket_preview_sims_reclaim", combined)
        self.assertIn("trinket_simulator_enforce_single_warm_booted", combined)
        self.assertIn("trinket_derived_data_age_prune", combined)
        self.assertIn("trinket_run_env_self_clean_hygiene", text)
        self.assertIn("trinket_run_env_release_slots", text)
        self.assertIn("trinket_run_env_claim_self_clean_owner", text)
        self.assertIn("TRINKET_SELF_CLEAN_OWNER", text)
        self.assertIn("Simulator%20Devices", simctl)
        self.assertIn("Packages", derived)
        hygiene = text.split("trinket_run_env_self_clean_hygiene()", 1)[1].split(
            "trinket_run_env_claim_self_clean_owner", 1
        )[0]
        self.assertIn("trinket_preview_sims_reclaim", hygiene)
        self.assertIn("trinket_simulator_enforce_single_warm_booted", hygiene)
        self.assertIn("trinket_derived_data_age_prune", hygiene)
        install = text.split("trinket_run_env_install_self_clean()", 1)[1].split(
            "trinket_bind_agent_slot", 1
        )[0] if "trinket_bind_agent_slot" in text else text.split("trinket_run_env_install_self_clean()", 1)[1]
        self.assertIn("trinket_run_env_self_clean_hygiene", install)
        self.assertNotIn("trinket_run_env_install_test_simulator_cleanup", text)
        release = text.split("trinket_run_env_release_slots()", 1)[1].split(
            "trinket_run_env_install_release_trap", 1
        )[0]
        self.assertIn("TRINKET_SELF_CLEAN_OWNER", release)
        self.assertIn("trinket_run_env_self_clean_hygiene", release)
        single = simctl.split("trinket_simulator_enforce_single_warm_booted()", 1)[1].split(
            "trinket_run_env_cleanup_test_artifacts", 1
        )[0] if "trinket_run_env_cleanup_test_artifacts" in simctl else simctl.split("trinket_simulator_enforce_single_warm_booted()", 1)[1]
        self.assertIn('TRINKET_CLEANUP_SINGLE_WARMED:-1', single)
        self.assertIn("trinket_simulator_is_shared_name", single)
        self.assertIn("trinket_simulator_is_active_agent_name", single)
        self.assertIn("trinket_simulator_is_shared_name", simctl)
        self.assertIn("Trinket CI", simctl)
        self.assertIn("trinket_simulator_is_managed_name", simctl)
        self.assertNotIn("TRINKET_CLEANUP_IDLE_POOL", text)
        self.assertNotIn("TRINKET_CLEANUP_EXCESS_SIMULATORS", text)
        self.assertNotIn("TRINKET_KEEP_DIAGNOSTICS", text)
        self.assertNotIn("TRINKET_SIM_SLOT_SKIP_ACQUIRE", text)
        self.assertNotIn("TRINKET_ARTIFACT_MAX_AGE_DAYS", text)
        self.assertIn('TRINKET_MAX_AGENT_SIMS:-1', text)
        self.assertFalse((ROOT / "Scripts" / "clean-dev-artifacts.sh").exists())

if __name__ == "__main__":
    unittest.main()
