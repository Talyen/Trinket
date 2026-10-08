#!/usr/bin/env python3

from __future__ import annotations

SCRIPT_INPUTS = (
    '.github/workflows/ci.yml',
    '.githooks/pre-push',
    'Scripts/pre-push-paths.py',
    'Scripts/ci-gate.sh',
    'Scripts/config/cheap-slices.txt',
    'Scripts/handoff.sh',
    'Scripts/lib/args.sh',
    'Scripts/lib/cheap-slices.sh',
    'Scripts/lib/gate.sh',
    'Scripts/report-exhaustive-ci.py',
    'Scripts/build-inputs.env',
)


import os
import json
import shutil
import subprocess
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

import tempfile
from pathlib import Path

class CIGateScriptTests(ScriptRegressionTestCase):
    def test_every_unit_package_in_exactly_one_shard(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        from internal.cli import read_env_arrays
        import re

        packages = read_env_arrays(ROOT / "Scripts/build-inputs.env", ["TRINKET_TEST_PACKAGES"])["TRINKET_TEST_PACKAGES"]
        selection = load_script('ci_package_selection', 'ci-path-filter.py')
        self.assertEqual(sorted(packages), sorted(selection.all_packages()), 'missing or duplicate package owner')
        self.assertIn('fromJSON(needs.changes.outputs.unit-matrix)', workflow)

    def test_manual_runs_queue_while_pushes_supersede_branch_verification(self) -> None:
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("group: ci-${{ github.workflow }}-${{ github.ref }}\n", ci)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'push' }}", ci)

    def test_beta_validation_cannot_reuse_verified_builds_or_skip_on_commit_identity(self) -> None:
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn("github.event_name == 'schedule' && 'latest'", workflow)
        self.assertNotIn('schedule-guard:', workflow)
        tests = (ROOT / '.github/workflows/tests.yml').read_text()
        reuse = tests.split('  reuse:\n', 1)[1].split('  changes:\n', 1)[0]
        self.assertEqual(reuse.count("inputs.xcode-channel == 'verified'"), 2)

    def test_gate_transcript_keeps_the_original_failure_exit(self) -> None:
        workflow = (ROOT / '.github/workflows/gate.yml').read_text()
        command = workflow.split('        run: |\n', 1)[1].split('      - name:', 1)[0]
        command = '\n'.join(line[10:] for line in command.splitlines())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            scripts.mkdir()
            gate = scripts / 'ci-gate.sh'
            gate.write_text('#!/bin/bash\necho original failure >&2\nexit 65\n')
            gate.chmod(0o755)
            results = root / 'TestResults'
            result = subprocess.run(['bash', '-c', command], cwd=root, capture_output=True, text=True,
                                    env={**os.environ, 'RESULTS_DIR': str(results)})
            self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
            self.assertIn('original failure', (results / 'gate.log').read_text())
        stage = workflow.split('      - name: Stage bounded gate failure diagnostics', 1)[1]
        self.assertIn('if: failure()', stage)
        self.assertIn('--stage-gate-artifacts', stage)
        self.assertIn('retention-days: 1', stage)

    def test_advisory_report_uses_actual_paginated_shard_conclusions(self) -> None:
        module = load_script('exhaustive_report', 'report-exhaustive-ci.py')
        def job(name, outcome):
            return {'name': name, 'conclusion': outcome, 'status': 'completed', 'html_url': 'https://example.com/job'}
        for outcome, title, warning in (('success', 'passed', False), ('skipped', 'not run', False),
                                        ('failure', 'attention required', True), ('cancelled', 'attention required', True)):
            with self.subTest(outcome=outcome):
                pages = [{'jobs': [job('tests / CI OK', 'success')]},
                         {'jobs': [job('tests / Exhaustive UI (Collection)', outcome)]}]
                summary, warnings = module.report(pages)
                self.assertIn(f'Exhaustive UI: {title}', summary)
                self.assertIn(f'| {outcome} |', summary)
                self.assertEqual(bool(warnings), warning)
                self.assertNotIn('CI OK](', summary)
        self.assertTrue(module.report([{'jobs': []}])[1])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            jobs = root / 'jobs.json'
            jobs.write_text(json.dumps([{'jobs': [job('tests / Exhaustive UI (Battle)', 'failure')]}]))
            summary_path = root / 'summary.md'
            result = subprocess.run(['python3', str(ROOT / 'Scripts/report-exhaustive-ci.py'), str(jobs)],
                                    capture_output=True, text=True,
                                    env={**os.environ, 'GITHUB_STEP_SUMMARY': str(summary_path)})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('::warning::Advisory exhaustive shard', result.stdout)
            self.assertIn('attention required', summary_path.read_text())

    def test_ci_diff_review_is_advisory(self) -> None:
        text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"diff-review:\n(?:.*\n){0,8}    continue-on-error: true")
        self.assertNotRegex(text, r"ci-ok:\n(?:.*\n)*?needs:.*diff-review")

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
