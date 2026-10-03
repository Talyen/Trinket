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
import importlib.util
import json
import shutil
import subprocess
import unittest

from script_test_support import ROOT, ScriptRegressionTestCase

import tempfile
from pathlib import Path

class CIGateScriptTests(ScriptRegressionTestCase):
    def test_every_unit_package_in_exactly_one_shard(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        from internal.cli import read_env_arrays
        import re

        packages = read_env_arrays(ROOT / "Scripts/build-inputs.env", ["TRINKET_TEST_PACKAGES"])["TRINKET_TEST_PACKAGES"]
        from script_test_support import load_script
        selection = load_script('ci_package_selection', 'ci-path-filter.py')
        self.assertEqual(sorted(packages), sorted(selection.all_packages()), 'missing or duplicate package owner')
        self.assertIn('fromJSON(needs.changes.outputs.unit-matrix)', workflow)

    def test_manual_runs_queue_while_pushes_supersede_branch_verification(self) -> None:
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("group: ci-${{ github.workflow }}-${{ github.ref }}\n", ci)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'push' }}", ci)

    def test_idle_nightly_retries_until_actual_exhaustive_shards_pass(self) -> None:
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        command = workflow.split('        run: |\n', 1)[1].split('\n\n  tests:', 1)[0]
        command = '\n'.join(line[10:] for line in command.splitlines())
        command = command.replace('${{ github.run_id }}', '99')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / 'gh'
            gh.write_text('#!/bin/bash\n'
                          'if [[ "$*" == *"/jobs?"* ]]; then\n'
                          '  printf "%s\\n" "$SHARDS_PASSED"; exit "$JOBS_STATUS"\n'
                          'else\n'
                          '  printf "%s\\n" "$PREVIOUS"; exit "$RUNS_STATUS"\nfi\n')
            gh.chmod(0o755)
            cases = [
                ('1\t1\tcurrent\tsuccess', 'true', '0', '0', False),
                ('1\t1\tcurrent\tfailure', 'true', '0', '0', True),
                ('1\t1\tcurrent\tcancelled', 'true', '0', '0', True),
                ('1\t1\told\tsuccess', 'true', '0', '0', True),
                ('1\t1\tcurrent\tsuccess', 'false', '0', '0', True),
                ('1\t1\tcurrent\tsuccess', '', '0', '1', True),
                ('', '', '1', '0', True),
            ]
            for previous, shards, runs_status, jobs_status, should_run in cases:
                with self.subTest(previous=previous, shards=shards, jobs_status=jobs_status):
                    output = root / 'output'
                    output.write_text('')
                    env = {**os.environ, 'PATH': f"{root}:{os.environ['PATH']}",
                           'REPO': 'fixture/repo', 'SHA': 'current', 'GITHUB_OUTPUT': str(output),
                           'PREVIOUS': previous, 'SHARDS_PASSED': shards,
                           'RUNS_STATUS': runs_status, 'JOBS_STATUS': jobs_status}
                    result = subprocess.run(['bash', '-c', command], cwd=root, env=env,
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(output.read_text(), f'should-run={str(should_run).lower()}\n')

    @unittest.skipUnless(shutil.which('jq'), 'jq is needed to validate GitHub API queries')
    def test_nightly_query_distinguishes_failure_missing_and_intentional_idle_skip(self) -> None:
        import re
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        query = re.findall(r"--jq '([^']+)'", workflow)[-1]
        def shard(outcome):
            return {'name': 'tests / Exhaustive UI (Battle)', 'conclusion': outcome}
        cases = [
            ([{'jobs': [shard('success')]}, {'jobs': [shard('success')]}], True),
            ([{'jobs': [shard('success')]}, {'jobs': [shard('failure')]}], False),
            ([{'jobs': [shard('skipped')]}], False),
            ([{'jobs': [shard('cancelled')]}], False),
            ([{'jobs': []}], False),
            ([{'jobs': [{'name': 'tests', 'conclusion': 'skipped'}]}], True),
        ]
        for pages, passed in cases:
            with self.subTest(pages=pages):
                result = subprocess.run(['jq', '-r', query], input=json.dumps(pages),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), str(passed).lower())

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
        self.assertIn('retention-days: 7', stage)

    def test_advisory_report_uses_actual_paginated_shard_conclusions(self) -> None:
        spec = importlib.util.spec_from_file_location('exhaustive_report', ROOT / 'Scripts/report-exhaustive-ci.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
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
