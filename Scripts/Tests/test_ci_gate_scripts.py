#!/usr/bin/env python3

from __future__ import annotations

import os
import json
import shutil
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase, load_script, run_captured, write_executable, write_json

import tempfile
from pathlib import Path

class CIGateScriptTests(ScriptRegressionTestCase):
    def test_full_gate_rejects_a_failed_second_generation_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, ('Scripts/lib/gate.sh',))
            for name in ('generate.sh', 'test.sh', 'test-scripts.sh', 'assert-generated-output.sh'):
                write_executable(root / 'Scripts' / name, '#!/bin/bash\n' 'if [[ "${1:-}" == --idempotent ]]; then ' 'exit "${IDEMPOTENCE_STATUS:-0}"; fi\n')
            command = '''
source Scripts/lib/gate.sh
trinket_gate_ensure_tools() { :; }
trinket_run_env_init() { RESULTS_DIR=results; }
touch_generate_stamp() { :; }
trinket_log_section() { :; }
trinket_run_gate_slices() { :; }
trinket_run_full_gate
'''
            for status in (0, 17):
                with self.subTest(idempotence_status=status):
                    result = run_captured(['bash', '-eu', '-c', command], cwd=root, env=self.verification_environment(IDEMPOTENCE_STATUS=str(status)))
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('jq'), 'Release verification requires jq')
    def test_release_requires_green_push_ci_on_main(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text()
        command = workflow.split('        run: |\n', 1)[1].split('\n  github-release:', 1)[0]
        command = '\n'.join(line[10:] for line in command.splitlines())
        failed_push = dict(event='push', head_branch='main', status='completed',
                           conclusion='failure', html_url='https://example.com/main')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_executable(
                root / 'gh',
                '#!/usr/bin/env python3\n'
                'import json, os, subprocess, sys\n'
                'endpoint = sys.argv[2]\n'
                'if "/commits/" in endpoint: data = {"sha": "abc"}\n'
                'elif "/compare/" in endpoint: data = {"status": "identical"}\n'
                'else: data = json.loads(os.environ["RUNS"])\n'
                'result = subprocess.run([os.environ["JQ"], "-r", sys.argv[-1]], '
                'input=json.dumps(data), text=True)\n'
                'sys.exit(result.returncode)\n',
            )
            for newest, expected in (
                ({**failed_push, 'event': 'workflow_dispatch', 'conclusion': 'success'}, 1),
                ({**failed_push, 'head_branch': 'other', 'conclusion': 'success'}, 1),
                ({**failed_push, 'conclusion': 'success'}, 0),
            ):
                with self.subTest(newest=newest):
                    result = run_captured(
                        ['bash', '-c', command],
                        timeout=10,
                        env={
                            **os.environ,
                            'PATH': f'{root}:{os.environ["PATH"]}',
                            'REPO': 'owner/repo',
                            'TAG': 'v1.0.0',
                            'JQ': shutil.which('jq'),
                            'RUNS': json.dumps({'workflow_runs': [newest, failed_push]}),
                        },
                    )
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    self.assertIn('Trinket CI', result.stdout)

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
            (scripts / 'ci-run-budget.py').write_text((ROOT / 'Scripts/ci-run-budget.py').read_text())
            shutil.copytree(ROOT / 'Scripts/internal', scripts / 'internal', ignore=shutil.ignore_patterns('__pycache__'))
            (scripts / 'config').mkdir()
            for name in ('diagnostic-limits.env', 'infrastructure-patterns.env'):
                shutil.copyfile(ROOT / 'Scripts/config' / name, scripts / 'config' / name)
            write_executable(scripts / 'ci-gate.sh', '#!/bin/bash\necho original failure >&2\nexit 65\n')
            results = root / 'TestResults'
            run_captured(['bash', '-c', command], cwd=root, env={**os.environ, 'RESULTS_DIR': str(results)}, expected=65)
            self.assertIn('original failure', (results / 'gate.log').read_text())
        stage = workflow.split('      - name: Stage bounded gate failure diagnostics', 1)[1]
        self.assertIn('if: failure()', stage)
        self.assertIn('--stage-gate-artifacts', stage)
        self.assertIn('retention-days: 14', stage)

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
            write_json(jobs, [{'jobs': [job('tests / Exhaustive UI (Battle)', 'failure')]}])
            summary_path = root / 'summary.md'
            result = run_captured(['python3', str(ROOT / 'Scripts/report-exhaustive-ci.py'), str(jobs)], env={**os.environ, 'GITHUB_STEP_SUMMARY': str(summary_path)}, expected=0)
            self.assertIn('::warning::Advisory exhaustive shard', result.stdout)
            self.assertIn('attention required', summary_path.read_text())

    def test_requested_ui_aggregate_fails_on_skipped_failed_or_unavailable_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            jobs = Path(directory) / 'jobs.json'
            for outcome, expected in [('success', 0), ('skipped', 1), ('failure', 1), ('cancelled', 1), (None, 1)]:
                pages = [{'jobs': [] if outcome is None else [{'name': 'tests / Exhaustive UI (All)',
                    'conclusion': outcome, 'status': 'completed', 'html_url': 'https://example.com/job'}]}]
                write_json(jobs, pages)
                result = run_captured(['python3', str(ROOT / 'Scripts/report-exhaustive-ci.py'), str(jobs), '--require-execution'])
                self.assertEqual(result.returncode, expected, result.stderr)

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
            result = run_captured([str(script), "--print-command", *args], cwd=ROOT, expected=0)
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
        missing = run_captured([str(ROOT / "Scripts" / "handoff.sh"), "--dry-run"], cwd=ROOT)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("requires --paths", missing.stderr)
        run_captured([str(ROOT / "Scripts" / "handoff.sh"), "--dry-run", "--working-tree"], cwd=ROOT, expected=0)

    def test_cheap_slices_require_a_readable_nonempty_registry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / "slices"
            script = 'source Scripts/lib/cheap-slices.sh; TRINKET_CHEAP_SLICES_CONFIG="$1"; trinket_run_cheap_slices'
            for content, status in ((None, 1), ("# empty\n", 1), ("exit 17\n", 17), ("true\n", 0)):
                if content is not None:
                    registry.write_text(content)
                result = run_captured(["bash", "-eu", "-c", script, "_", str(registry)], cwd=ROOT)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)



if __name__ == "__main__":
    unittest.main()
