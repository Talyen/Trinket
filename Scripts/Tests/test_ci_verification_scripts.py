#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase

class CIVerificationScriptTests(ScriptRegressionTestCase):
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

    def test_build_inputs_include_xctestplans(self) -> None:
        text = (ROOT / "Scripts" / "build-freshness.sh").read_text(encoding="utf-8")
        owner = (ROOT / "Scripts" / "build-inputs.env").read_text(encoding="utf-8")
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
        self.assertNotIn("checkout-ci", workflow)
        self.assertIn("Smoke tests (${{ matrix.name }})", workflow)
        self.assertIn("needs.changes.outputs.infra", workflow)
        self.assertNotIn("actions/cache/restore@", workflow)
        self.assertIn("stage-ci-test-artifact.sh", text)
        cache_key = (
            ROOT / ".github" / "actions" / "build-cache-key" / "action.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('git rev-parse "HEAD:Raw Assets"', cache_key)
        checkout = (
            ROOT / ".github" / "actions" / "checkout-trinket" / "action.yml"
        ).read_text(encoding="utf-8")
        sparse_list = checkout.split("sparse-checkout: |", 1)[1].split("- name:", 1)[0]
        self.assertIn(".github", sparse_list)
        self.assertIn("StoreKit", sparse_list)
        self.assertNotIn("Raw Assets", sparse_list)

    def test_ci_gate_fast_skips_generation_and_style(self) -> None:
        text = (ROOT / "Scripts" / "ci-gate.sh").read_text(encoding="utf-8")
        self.assertIn("--fast", text)
        self.assertIn("=== Fast gate checks passed ===", text)
        self.assertIn("cheap-slices", text)
        cheap = (ROOT / "Scripts" / "config" / "cheap-slices.txt").read_text(encoding="utf-8")
        self.assertIn("check-module-boundaries.sh", cheap)
        self.assertIn("check-api-bans.sh", cheap)
        self.assertIn("release-notes.sh validate", cheap)

    def test_agent_push_gate_skips_generate_when_classification_does_not_need_it(self) -> None:
        text = (ROOT / "Scripts" / "agent-push-gate.sh").read_text(encoding="utf-8")
        self.assertIn("TRINKET_NEEDS_CONTENT_GENERATION", text)
        self.assertIn("TRINKET_NEEDS_PROJECT_GENERATION", text)
        self.assertIn("skip generate (no content, project, or asset inputs)", text)

    def test_pre_push_path_scopes_style_to_pushed_swift(self) -> None:
        text = (ROOT / ".githooks" / "pre-push").read_text(encoding="utf-8")
        self.assertIn('test.sh style "${style_swift[@]}"', text)
        self.assertIn("check-api-bans.sh", text)
        self.assertIn("check-agent-invariants.sh", text)
        self.assertIn("test-package.sh", text)
        self.assertLess(text.find("agent-push-gate.sh"), text.find("test-package.sh"))
        self.assertIn('"$remote_sha..$local_sha"', text)
        self.assertIn("push_lines+=", text)
        self.assertNotIn("./Scripts/test.sh style\n", text)
        # Pre-push reruns safeguards unconditionally: no receipt reuse.
        self.assertNotIn("handoff-receipt", text)
        self.assertNotIn("receipt_can_skip", text)
        self.assertNotIn("Reusing green handoff", text)
        self.assertNotIn("receipt reused", text.lower())
        # Style, generation, and touched-package checks are unconditional.
        self.assertIn("=== Pre-push: style", text)
        self.assertIn("=== Pre-push: agent push gate", text)
        self.assertIn("=== Pre-push: path-scoped package tests ===", text)
        self.assertIn('SKIP_GENERATE=1 ./Scripts/test-package.sh "${TRINKET_PACKAGES[@]}"', text)

    def test_no_handoff_receipt_code_remains(self) -> None:
        self.assertFalse((ROOT / "Scripts" / "lib" / "handoff-receipt.sh").exists())
        for path in (
            ROOT / "Scripts" / "handoff.sh",
            ROOT / "Scripts" / "agent-push-gate.sh",
            ROOT / ".githooks" / "pre-push",
            ROOT / "Scripts" / "README.md",
            ROOT / "Docs" / "Platform" / "Release.md",
        ):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("handoff-receipt", text, str(path))
            self.assertNotIn("handoff_receipt", text, str(path))
            self.assertNotIn("handoff-receipt.json", text, str(path))
        self.assertNotIn(
            "receipt reused",
            (ROOT / "Scripts" / "agent-push-gate.sh").read_text(encoding="utf-8").lower(),
        )
        self.assertNotIn(
            "Reusing green handoff",
            (ROOT / ".githooks" / "pre-push").read_text(encoding="utf-8"),
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

    def test_ci_diagnostics_rejects_overlapping_artifact_destinations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / "run" / "TestResults"
            results.mkdir(parents=True)
            evidence = results / "raw" / "failure.log"
            evidence.parent.mkdir()
            evidence.write_text("failure evidence\n")
            alias = root / "alias"
            alias.symlink_to(results.parent, target_is_directory=True)
            for destination in (results.parent, alias, results / "raw" / "artifact"):
                with self.subTest(destination=destination):
                    evidence.parent.mkdir(parents=True, exist_ok=True)
                    evidence.write_text("failure evidence\n")
                    result = subprocess.run(
                        [str(ROOT / "Scripts/ci-diagnostics.sh"), "--stage-artifacts", str(results), str(destination)],
                        cwd=ROOT, capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(evidence.read_text(), "failure evidence\n")

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
            env = {**os.environ}
            env.pop("TRINKET_DIAGNOSTICS_SESSION_ID", None)
            unscoped = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(unscoped.returncode, 0, unscoped.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["distinct_sessions"], 2)
            self.assertIn("Warning:", payload["detail"])
            self.assertIn("--reset", payload["session_warning"])

    def test_shared_runs_receive_distinct_sessions_and_nested_retains_parent(self) -> None:
        run_env = ROOT / "Scripts" / "run-env.sh"
        self.assertIn(
            "trinket_run_env_ensure_diagnostics_session",
            run_env.read_text(encoding="utf-8"),
        )

        def init_session(extra_env: dict[str, str]) -> str:
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1" && unset TRINKET_ISOLATE TRINKET_RUN_ID TRINKET_DIAGNOSTICS_SESSION_ID '
                    "DERIVED_DATA_PATH RESULTS_DIR TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT && "
                    "trinket_run_env_init >/dev/null && printf '%s' \"$TRINKET_DIAGNOSTICS_SESSION_ID\"",
                    "_",
                    str(run_env),
                ],
                cwd=ROOT,
                env={**os.environ, **extra_env},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            session = result.stdout.strip()
            self.assertTrue(session)
            return session

        first = init_session({})
        second = init_session({})
        self.assertNotEqual(first, second)

        nested = subprocess.run(
            [
                "bash",
                "-c",
                'source "$1" && unset TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR '
                'TRINKET_SIMULATOR_NAME TRINKET_AGENT_SLOT && '
                'export TRINKET_DIAGNOSTICS_SESSION_ID="parent-session" && '
                "trinket_run_env_init >/dev/null && printf '%s' \"$TRINKET_DIAGNOSTICS_SESSION_ID\"",
                "_",
                str(run_env),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(nested.returncode, 0, nested.stderr)
        self.assertEqual(nested.stdout.strip(), "parent-session")

    def test_orchestrations_establish_inheritable_session(self) -> None:
        for script in ("handoff.sh", "test-deploy.sh"):
            text = (ROOT / "Scripts" / script).read_text(encoding="utf-8")
            self.assertIn("TRINKET_DIAGNOSTICS_SESSION_ID", text, script)
            self.assertIn("export TRINKET_DIAGNOSTICS_SESSION_ID", text, script)
        # Nested package commands inherit via run-env preservation, not a fresh id.
        run_env = (ROOT / "Scripts" / "run-env.sh").read_text(encoding="utf-8")
        self.assertIn(
            'if [[ -n "${TRINKET_DIAGNOSTICS_SESSION_ID:-}" ]]; then',
            run_env,
        )

    def test_aggregation_selects_newest_failed_while_retaining_old(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory) / "TestResults"
            results.mkdir()
            for label, session, seconds in (
                ("old-fail", "session-old-fail", "00"),
                ("new-fail", "session-new-fail", "30"),
            ):
                (results / f"{label}-invocation.json").write_text(
                    json.dumps(
                        {
                            "label": label,
                            "session_id": session,
                            "status": "failed",
                            "exit_code": 65,
                            "result_bundle": "",
                            "generated_at": f"2026-08-20T00:00:{seconds}Z",
                        }
                    ),
                    encoding="utf-8",
                )
            aggregate = results / "current.json"
            env = {**os.environ}
            env.pop("TRINKET_DIAGNOSTICS_SESSION_ID", None)
            unscoped = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "ci-diagnostics.py"), str(results), str(aggregate)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(unscoped.returncode, 0, unscoped.stderr)
            payload = json.loads(aggregate.read_text(encoding="utf-8"))
            self.assertEqual(payload["session_id"], "session-new-fail")
            self.assertEqual(payload["recorded_invocations"], 1)
            self.assertEqual(payload["failed_invocations"], 1)
            # Old retained failures remain available for forensic use.
            self.assertTrue((results / "old-fail-invocation.json").exists())
            self.assertTrue((results / "new-fail-invocation.json").exists())

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

    def test_handoff_default_headless_compile_proof(self) -> None:
        environment = os.environ.copy()
        environment.pop("TRINKET_ENABLE_SMOKE", None)
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Trinket/Features/Play/Mystery/MysteryChoiceCard.swift",
            ],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/build.sh", plan)
        self.assertNotIn("SmokeShellTests", plan)

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

    def test_compile_only_packages_are_disjoint_from_test_packages(self) -> None:
        owner = (ROOT / "Scripts" / "build-inputs.env").read_text(encoding="utf-8")
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
        classifier = (ROOT / "Scripts" / "change-classification.sh").read_text(
            encoding="utf-8"
        )
        # The package membership gate must read the registry, not a
        # second hardcoded list that can drift from build-inputs.env.
        self.assertIn(
            '"${TRINKET_TEST_PACKAGES[@]}" "${TRINKET_COMPILE_ONLY_PACKAGES[@]}"',
            classifier,
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

    def test_shared_fixture_verification_routes(self) -> None:
        root = "Packages/TrinketTestSupport"
        fixtures = [
            f"{root}/Sources/TrinketTestSupport/{name}.swift"
            for name in ("CombatantFixtures", "BattlePartyFixtures", "ItemFixtures")
        ]
        consumers = {"BattleEngine", "TrinketAppState", "TrinketBattleFeature", "TrinketFeatureSupport"}
        cases = [
            *[(name, [path], consumers, False, False) for name, path in zip(
                ("combatant", "party", "item"), fixtures
            )],
            ("manifest", [f"{root}/Package.swift"], consumers, False, True),
            ("deleted", [f"{root}/Sources/TrinketTestSupport/DeletedFixture.swift"], consumers, False, False),
            ("deduplicated", fixtures + ["Packages/BattleEngine/Tests/BattleEngineTests/BattleStateTests.swift"], consumers, False, False),
            ("mixed-app", [fixtures[0], "Trinket/App/TrinketApp.swift"], consumers, True, False),
            ("docs", [f"{root}/README.md"], set(), False, False),
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

    def test_idempotence_checks_outputs_even_with_a_fresh_stamp(self) -> None:
        for initial, generator, expected in (
            ("stable", "printf stable > output", 0),
            ("damaged", "printf stable > output", 1),
            ("stable", "printf churn >> output", 1),
        ):
            with self.subTest(initial=initial, generator=generator), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "Scripts/config").mkdir(parents=True)
                (root / "Trinket.xcodeproj").mkdir()
                (root / "results").mkdir()
                for filename in ("assert-generated-output.sh", "build-freshness.sh", "build-inputs.env"):
                    shutil.copy2(ROOT / "Scripts" / filename, root / "Scripts" / filename)
                (root / "Scripts/config/generated-paths.tsv").write_text("content|output\n")
                (root / "Scripts/run-env.sh").write_text(
                    'trinket_run_env_init() { export RESULTS_DIR="$PWD/results"; }\n'
                )
                generate = root / "Scripts/generate.sh"
                generate.write_text('#!/bin/bash\n[[ "$*" == "--force-xcodegen" && "$TRINKET_FORCE_ABILITY_DUMP" == 1 ]] || exit 9\nprintf called >> calls\n' + generator + "\n")
                generate.chmod(0o755)
                identifier = "A" * 24
                (root / "Trinket.xcodeproj/project.pbxproj").write_text(
                    "Begin PBXNativeTarget section\n"
                    + identifier + " /* target */\nEnd PBXNativeTarget section\n"
                )
                (root / "Smoke.xctestplan").write_text(json.dumps({"identifier": identifier}))
                (root / "output").write_text(initial)
                stamp = root / "results/.last-generate.stamp"
                stamp.touch()
                os.utime(stamp, (time.time() + 60, time.time() + 60))
                result = subprocess.run(
                    ["bash", "Scripts/assert-generated-output.sh", "--idempotent"],
                    cwd=root, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), "called")

    def test_generation_reuses_dirty_inputs_and_detects_edits_and_deletions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            for filename in ("build-freshness.sh", "build-inputs.env"):
                shutil.copy2(ROOT / "Scripts" / filename, root / "Scripts" / filename)
            generate = root / "Scripts/generate.sh"
            generate.write_text('#!/bin/bash\necho generated >> calls\n')
            generate.chmod(0o755)
            script = """
source Scripts/build-freshness.sh
content_generation_inputs=(input); project_generation_inputs=(project); asset_generation_inputs=(asset)
touch input project asset
git() { printf ' M input\\n'; }
prepare_generated_inputs results
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 1 ]]
printf changed > input
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 2 ]]
rm input
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 3 ]]
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 3 ]]
printf changed > asset
touch_generate_stamp results
prepare_generated_inputs results
[[ $(wc -l < calls) -eq 4 ]]
"""
            result = subprocess.run(["bash", "-eu", "-c", script], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generation_tracks_shared_generator_helpers(self) -> None:
        for relative, expected in (
            ("Scripts/lib/project-generation.sh", ""),
            ("Scripts/tool-versions.env", ""),
            ("Scripts/lib/ci-tools.d/xcodegen.sh", ""),
            ("Trinket.xcodeproj/project.pbxproj", ""),
            ("Scripts/internal/content/content_codegen_modifiers.py", "--skip-xcodegen"),
            ("Scripts/internal/content/content_codegen_triggers.py", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalogBasic.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/MysteryEventPool+Wilds.swift", "--skip-xcodegen"),
            ("Packages/TrinketContent/Sources/TrinketContent/Encounters/RecruitEventPool.swift", "--skip-xcodegen"),
            ("Scripts/lib/media-assets.sh", "--assets"),
            ("Scripts/prepare-assets.sh", "--assets"),
        ):
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "Scripts/lib").mkdir(parents=True)
                (root / "ContentManifest").mkdir()
                (root / "ContentManifest/input.tsv").touch()
                (root / "ArtManifest").mkdir()
                (root / "ArtManifest/input.tsv").touch()
                (root / "project.yml").touch()
                for filename in ("build-freshness.sh", "build-inputs.env"):
                    shutil.copy2(ROOT / "Scripts" / filename, root / "Scripts" / filename)
                (root / relative).parent.mkdir(parents=True, exist_ok=True)
                (root / relative).touch()
                generate = root / "Scripts/generate.sh"
                generate.write_text('#!/bin/bash\nprintf "%s" "$*" > calls\n')
                generate.chmod(0o755)
                (root / "results").mkdir()
                stamp = root / "results/.last-generate.stamp"
                subprocess.run(["bash", "-ec", "source Scripts/build-freshness.sh; touch_generate_stamp results true"], cwd=root, check=True)
                os.utime(root / relative, (time.time() + 60, time.time() + 60))
                result = subprocess.run(
                    ["bash", "-ec", "source Scripts/build-freshness.sh; prepare_generated_inputs results"],
                    cwd=root, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((root / "calls").read_text(), expected)

    def test_asset_dispatch_validates_before_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            shutil.copy2(ROOT / "Scripts/prepare-assets.sh", root / "Scripts/prepare-assets.sh")
            for kind in ("art", "cinematic", "audio", "app-icon"):
                pipeline = root / "Scripts" / f"prepare-{kind}-assets.sh"
                if kind == "app-icon":
                    pipeline = root / "Scripts/prepare-app-icon.sh"
                pipeline.write_text('#!/bin/bash\nprintf "%s %s\\n" "$0" "$*" >> calls\n')
                pipeline.chmod(0o755)
            for arguments in (("--kind", "typo"), ("--kind", "art", "extra"), ("--kind",)):
                with self.subTest(arguments=arguments):
                    result = subprocess.run(
                        ["bash", "Scripts/prepare-assets.sh", *arguments],
                        cwd=root, capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((root / "calls").exists())
            result = subprocess.run(
                ["bash", "Scripts/prepare-assets.sh", "--kind", "sfx"],
                cwd=root, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "calls").read_text(), "Scripts/prepare-audio-assets.sh sfx\n")

    def test_test_package_records_timing_log(self) -> None:
        text = (ROOT / "Scripts" / "test-package.sh").read_text(encoding="utf-8")
        self.assertIn("test-timing.py record", text)
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
        stamp = (ROOT / "Scripts" / "build-freshness.sh").read_text(encoding="utf-8")
        self.assertIn("package_symroot()", stamp)
        self.assertIn("package_objroot()", stamp)
        self.assertIn("package_shared_precomps_dir()", stamp)
        self.assertIn("Packages/.DerivedData", stamp)
        # build-for-testing.sh delegates package builds to the single parallel
        # owner instead of re-implementing the xargs/tenant protocol.
        build_for_testing = (ROOT / "Scripts" / "build-for-testing.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("test-package.sh --build-for-testing", build_for_testing)
        self.assertIn("TRINKET_BUILD_FINGERPRINTS_APP", build_for_testing)
        helpers = (ROOT / "Scripts" / "lib" / "test-helpers.sh").read_text(encoding="utf-8")
        self.assertNotIn("trinket_run_package_tests", helpers)
        test_sh = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        # test.sh unit collapses into one package-test pass via the parallel
        # owner: no separate generic prebuild, no orchestration helper.
        self.assertNotIn("trinket_run_package_tests", test_sh)
        self.assertNotIn("test-package.sh --build-for-testing", test_sh)
        self.assertIn('"${TRINKET_TEST_PACKAGES[@]}"', test_sh)

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


if __name__ == "__main__":
    unittest.main()
