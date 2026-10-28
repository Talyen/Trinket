"""Regressions for evidence preservation and lightweight tooling boundary cases."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import subprocess
import time
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import load_script
from performance_test_support import report
from internal.performance.performance_model import load_results_reports
from internal.profile_exports import BoundedLog

collect = load_script('evidence_collect', 'collect-performance-results.py')
aggregate = load_script('evidence_aggregate', 'aggregate-performance-results.py')
environment = load_script('evidence_environment', 'performance_environment.py')
phase = load_script('evidence_phase', 'phase-timing.py')
timing = load_script('evidence_timing', 'test-timing.py')
source_times = load_script('evidence_source_times', 'build-source-times.py')


class ToolingEvidenceTests(unittest.TestCase):
    def collect_reports(self, root):
        output = root / 'reports.json'
        with patch.object(sys, 'argv', ['collect', str(root), str(output)]), patch('builtins.print'):
            status = collect.main()
        return status, json.loads(output.read_text())

    def test_collection_failure_survives_into_comparison(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'capture.log').write_text(collect.MARKER + json.dumps(report()) + '\n' + collect.MARKER + '{broken}\n')
            status, payload = self.collect_reports(root)
            self.assertEqual(status, 1)
            self.assertEqual(len(payload['reports']), 1)
            with self.assertRaisesRegex(SystemExit, 'collection failed'):
                load_results_reports(payload)
            self.assertEqual(load_results_reports({'reports': [report()]}), [report()])

    def test_unreadable_log_does_not_erase_other_measurements(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'good.log').write_text(collect.MARKER + json.dumps(report()) + '\n')
            (root / 'broken.log').symlink_to(root / 'missing')
            status, payload = self.collect_reports(root)
            self.assertEqual(status, 1)
            self.assertEqual(len(payload['reports']), 1)
            self.assertIn('cannot read performance log', payload['collectionFailures'][0])

    def test_invalid_capture_configuration_fails_before_running_commands(self):
        for repetitions, timeout in (('0', '1200'), ('-1', '1200'), ('1', '0'), ('1', '-1'), ('1', 'invalid')):
            with self.subTest(repetitions=repetitions, timeout=timeout), \
                    patch.object(sys, 'argv', ['environment', '/unused.json', repetitions]), \
                    patch.dict(os.environ, TRINKET_XCODE_WALL_TIMEOUT_SECONDS=timeout), \
                    patch.object(environment, 'command') as command, self.assertRaises(SystemExit):
                environment.main()
            command.assert_not_called()

    def test_untracked_build_configuration_and_scripts_have_content_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = [root / ('input' + suffix) for suffix in ('.yml', '.yaml', '.plist', '.xcconfig', '.mjs', '.rb')]
            for source in sources:
                source.write_text('build input')
            def command(*args, raw=False, **kwargs):
                if args[:2] == ('git', 'ls-files'):
                    return b'\0'.join(os.fsencode(path) for path in sources) + b'\0'
                return b'diff' if raw else 'fixture'
            output = root / 'environment.json'
            with patch.object(sys, 'argv', ['environment', str(output), '1']), \
                    patch.object(environment, 'command', side_effect=command):
                environment.main()
            hashes = json.loads(output.read_text())['untrackedSourceSHA256']
            self.assertEqual(hashes, {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources})

    def aggregate_reports(self, root, reports):
        (root / 'results.json').write_text(json.dumps({'reports': reports}))
        (root / 'baseline.json').write_text(json.dumps({'scenarios': ['navigation'], 'goals': {
            'minimumAverageFPS': 59, 'minimumOnePercentLowFPS': 59, 'maximumSevereStallCount': 0}}))
        args = ['aggregate', '--results', str(root / 'results.json'), '--baseline', str(root / 'baseline.json'),
                '--output', str(root / 'aggregate.json'), '--summary', str(root / 'summary.md'), '--expected-repetitions', '1']
        with patch.object(sys, 'argv', args), patch('builtins.print'):
            status = aggregate.main()
        return status, json.loads((root / 'aggregate.json').read_text()), (root / 'summary.md').read_text()

    def test_missing_measurements_are_not_reported_as_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            status, _, summary = self.aggregate_reports(Path(directory), [])
            self.assertEqual(status, 1)
            self.assertIn('| navigation | 0 | N/A | N/A | N/A | N/A |', summary)

    def test_duplicate_iterations_do_not_contribute_to_statistics(self):
        with tempfile.TemporaryDirectory() as directory:
            status, payload, _ = self.aggregate_reports(Path(directory), [report(), report()])
            self.assertEqual(status, 1)
            self.assertEqual(payload['scenarios']['navigation']['metrics'], {})
            self.assertIn('found [1, 1]', payload['failures'][0])
            status, payload, _ = self.aggregate_reports(Path(directory), [report()])
            self.assertEqual(status, 0)
            self.assertEqual(payload['scenarios']['navigation']['metrics']['averageFPS']['median'], 59.1)

    def test_duration_rounding_carries_into_the_next_minute(self):
        self.assertEqual(timing.format_seconds(119.9), '2m 0s')
        self.assertEqual(timing.format_seconds(60), '1m 0s')
        self.assertEqual(timing.format_seconds(1.25), '1.2s')

    def test_invalid_log_budget_preserves_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'command.log'
            path.write_bytes(b'important diagnostics')
            with self.assertRaisesRegex(ValueError, 'budget is too small'):
                BoundedLog(path, 1)
            self.assertEqual(path.read_bytes(), b'important diagnostics')

    def test_unchanged_timestamp_restore_does_not_write_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source.swift'
            source.write_text('let x = 1')
            with patch.object(source_times, 'inputs', return_value=[('source.swift', source)]), patch('builtins.print'):
                source_times.process(root, 'record')
                with patch.object(source_times.os, 'utime') as utime:
                    self.assertEqual(source_times.process(root, 'restore'), 0)
                    utime.assert_not_called()

    def test_phase_timing_spans_separate_interpreters(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, 'RESULTS_DIR': directory}
            # Delaying only the begin interpreter exposes per-process clock origins.
            started = subprocess.check_output([sys.executable, '-c',
                'import time, runpy, sys; time.sleep(.2); sys.argv = [sys.argv[1], "begin"]; '
                'runpy.run_path(sys.argv[0], run_name="__main__")', phase.__file__],
                env={**env, 'PYTHONPATH': str(Path(phase.__file__).parent)}, text=True).strip()
            time.sleep(.1)
            subprocess.run([sys.executable, phase.__file__, 'end', 'build', started, 'fixture'],
                           env=env, check=True, capture_output=True, text=True, timeout=10)
            entry = json.loads((Path(directory) / 'phase-timing.jsonl').read_text())
            self.assertGreaterEqual(entry['seconds'], .1)
            self.assertLess(entry['seconds'], 10)

    def test_phase_cli_rejects_bad_commands_and_future_timestamps(self):
        with patch.object(phase, 'update_timing') as update, patch.object(phase.time, 'clock_gettime_ns', return_value=100), \
                contextlib.redirect_stderr(io.StringIO()):
            for args in ([], ['typo', 'build', '1', 'scope'], ['end'], ['end', 'build', '-1', 'scope'],
                         ['end', 'build', '101', 'scope']):
                with self.subTest(args=args), self.assertRaises(SystemExit):
                    phase.main(args)
            update.assert_not_called()
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, RESULTS_DIR=directory), \
                patch.object(phase, 'update_timing') as update, patch.object(phase.time, 'clock_gettime_ns', return_value=2000000000):
            phase.main(['end', 'build', '1000000000', 'scope'])
            self.assertEqual(update.call_args.kwargs['entry']['seconds'], 1)


if __name__ == '__main__':
    unittest.main()
