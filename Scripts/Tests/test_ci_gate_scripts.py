#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-gate.sh',
    'Scripts/config/cheap-slices.txt',
    'Scripts/handoff.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/gate.sh',
)


import os
import subprocess
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase

import tempfile
from pathlib import Path

class CIGateScriptTests(ScriptRegressionTestCase):
    def test_ci_diff_review_is_advisory(self) -> None:
        text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"diff-review:\n(?:.*\n){0,8}    continue-on-error: true")
        self.assertNotRegex(text, r"ci-ok:\n(?:.*\n)*?needs:.*diff-review")

    def test_ci_gate_fast_skips_generation_and_style(self) -> None:
        text = (ROOT / "Scripts" / "ci-gate.sh").read_text(encoding="utf-8")
        self.assertIn("--fast", text)
        self.assertIn('trinket_log_section "Fast gate checks passed"', text)
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


    def test_cheap_slices_require_a_readable_nonempty_registry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / "slices"
            script = 'source Scripts/lib/cheap-slices.sh; TRINKET_CHEAP_SLICES_CONFIG="$1"; trinket_run_cheap_slices'
            for content, status in ((None, 1), ("# empty\n", 1), ("exit 17\n", 17), ("true\n", 0)):
                if content is not None:
                    registry.write_text(content)
                result = subprocess.run(["bash", "-eu", "-c", script, "_", str(registry)], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)



if __name__ == "__main__":
    unittest.main()
