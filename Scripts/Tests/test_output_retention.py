"""Protect source, active work, and staged consumers while expiring disposable output."""

SCRIPT_INPUTS = (
    'Scripts/cleanup-outputs.py',
    'Scripts/diagnostic_maintenance.py',
    'Scripts/internal/output_retention.py',
    'Scripts/lib/output-retention.sh',
    'Scripts/lib/derived-data.sh',
    'Scripts/phase-timing.py',
    'Scripts/testflight.sh',
    'Scripts/handoff.sh',
    'Scripts/test-scripts.sh',
)

import contextlib
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

from script_test_support import ROOT, ScriptRegressionTestCase
from internal import output_retention as retention


class OutputRetentionTests(ScriptRegressionTestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.now = float(int(time.time()))
        self.processes = {123: ('Mon Oct 5 00:00:00 2026', 'fixture worker')}

    def output(self, name, age=86400, content='evidence'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        os.utime(path, (self.now - age, self.now - age))
        return path

    def clean(self, apply=True, experiments=False):
        with patch.object(retention, 'process_snapshot', return_value=self.processes):
            return retention.cleanup(self.root, apply=apply, experiments=experiments,
                                     now=self.now, receipts_dir=self.root / 'receipts', verbose=False)

    def test_dry_run_boundary_preserves_caches_source_and_release_state(self):
        expired = self.output('.DerivedData/HandoffResults/expired.log')
        fresh = self.output('.DerivedData/HandoffResults/fresh.log', age=86399)
        preserved = [self.output(name) for name in (
            'Packages/BattleEngine/Sources/source.swift', '.DerivedData/Build/product',
            '.DerivedData/packages/BattleEngine/Build/product',
            '.DerivedData/runs/agent-1/Build/product', '.tools/swiftlint',
            '.DerivedData/testflight/deployment/receipt.json',
            '.DerivedData/testflight/deployment/artifacts/Trinket.xcarchive/product')]
        self.assertEqual(self.clean(apply=False)[0], 1)
        self.assertTrue(expired.exists())
        self.assertEqual(self.clean()[0], 1)
        self.assertFalse(expired.exists())
        self.assertTrue(fresh.exists())
        self.assertTrue(all(path.exists() for path in preserved))

    def test_symlink_roots_children_and_escaping_controls_cannot_delete_source(self):
        source = self.output('authored/source.txt')
        directory = self.root / '.DerivedData/HandoffResults'
        directory.mkdir(parents=True)
        (directory / 'escape').symlink_to(source.parent, target_is_directory=True)
        self.clean()
        self.assertTrue(source.exists())
        self.assertFalse(retention.managed_path(directory / 'escape/source.txt', self.root))
        self.assertFalse(retention.managed_path(self.root.parent / 'outside', self.root))
        self.assertFalse(retention.managed_path(self.root / '.DerivedData/Build/product', self.root))
        nested = directory / 'nested'
        nested.mkdir()
        (nested / 'escape').symlink_to(source)
        os.utime(nested / 'escape', (0, 0), follow_symlinks=False)
        os.utime(nested, (0, 0))
        self.clean()
        self.assertTrue(source.exists())
        self.assertFalse(nested.exists())

    def test_owner_identity_keep_release_and_unknown_owner_protect_output(self):
        path = self.output('.DerivedData/HandoffResults/run/log', age=90000)
        folder = path.parent
        os.utime(folder, (0, 0))
        owner = folder / retention.OWNER
        owner.write_text(json.dumps({'pid': 123, 'started': self.processes[123][0]}))
        self.clean()
        self.assertTrue(path.exists())
        # PID reuse is not the same invocation; its obsolete output can expire.
        owner.write_text(json.dumps({'pid': 123, 'started': 'different start'}))
        keep = folder / retention.KEEP
        keep.touch()
        self.clean()
        self.assertTrue(path.exists())
        keep.unlink()
        owner.write_text('broken owner')
        self.clean()
        self.assertTrue(path.exists())
        owner.unlink()
        os.utime(folder, (0, 0))
        self.clean()
        self.assertFalse(path.exists())

    def test_active_lease_and_failed_process_snapshot_fail_closed(self):
        path = self.output('.DerivedData/HandoffResults/old.log')
        slot = self.root / '.DerivedData/.active-sim/agent-1.slot'
        slot.parent.mkdir()
        slot.write_text('123 fixture lease')
        self.clean()
        self.assertTrue(path.exists())
        with patch.object(retention, 'process_snapshot', side_effect=subprocess.CalledProcessError(1, 'ps')):
            with self.assertRaises(subprocess.CalledProcessError):
                retention.cleanup(self.root, apply=True)
        self.assertTrue(path.exists())

    def test_expire_raw_failures_individually_and_only_opt_in_experiments(self):
        old = self.output('.DerivedData/TestResults/raw/old.log')
        new = self.output('.DerivedData/TestResults/raw/current.log', age=1)
        experiment = self.output('.DerivedData/cpu-optimization-compile/Build/product', age=90000)
        # Rehoming a checkout refreshes directory dates without creating a build.
        os.utime(experiment.parent.parent, (self.now, self.now))
        self.clean()
        self.assertFalse(old.exists())
        self.assertTrue(new.exists())
        self.assertTrue(experiment.exists())
        with patch.object(retention.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 0, 'open', '')):
            self.clean(experiments=True)
        self.assertTrue(experiment.exists())
        self.clean(experiments=True)
        self.assertFalse(experiment.exists())

    def test_mixed_timing_dates_and_legacy_entries_do_not_rejuvenate(self):
        date = lambda value: datetime.fromtimestamp(value, timezone.utc).isoformat()
        entries = [{'run': 'expired', 'recorded_at': date(self.now - 86400)},
                   {'run': 'current', 'recorded_at': date(self.now - 100)}, {'run': 'legacy'}]
        path = self.output('.DerivedData/TestResults/timing-log.jsonl', age=100,
                           content='\n'.join(json.dumps(e) for e in entries)+'\n')
        self.clean(apply=False)
        self.assertEqual(len(path.read_text().splitlines()), 3)
        self.clean()
        retained = [json.loads(line) for line in path.read_text().splitlines()]
        self.assertEqual([e['run'] for e in retained], ['current', 'legacy'])
        self.assertIn('recorded_at', retained[1])
        retention.update_timing(path, entry={'run': 'next', 'recorded_at': date(self.now + 86400)}, now=self.now + 86400)
        self.assertEqual([json.loads(line)['run'] for line in path.read_text().splitlines()], ['next'])

    def test_begin_finish_preserves_comparison_and_failure_but_removes_success(self):
        for status, comparison, survives in ((0, False, False), (1, False, True), (0, True, True)):
            path = self.output(f'.DerivedData/HandoffResults/run-{status}-{comparison}/log', age=1).parent
            with patch.object(retention, 'process_snapshot', return_value=self.processes):
                retention.begin(path, self.root, 123)
                with self.assertRaisesRegex(ValueError, 'live owner'):
                    retention.begin(path, self.root, 123)
                retention.finish(path, self.root, 123, status, comparison=comparison)
            self.assertEqual(path.exists(), survives)

    def test_staged_diagnostics_survive_cleanup_and_aliases_cannot_target_results_root(self):
        from script_test_support import load_script
        maintenance = load_script('retention_maintenance', 'diagnostic_maintenance.py')
        results = self.root / 'TestResults'
        bundle = results / 'passed.xcresult'
        bundle.mkdir(parents=True)
        (bundle / 'result').write_text('passed result')
        manifest = results / 'passed-invocation.json'
        manifest.write_text(json.dumps({'status': 'passed', 'exit_code': 0,
                                       'result_bundle': str(bundle)}))
        (results / 'ci-diagnostics.json').write_text('{"category":"unknown"}')
        staged = self.root / 'staged'
        maintenance.stage(results, staged)
        keep = bundle / retention.KEEP
        keep.touch()
        maintenance.cleanup(results, False)
        self.assertTrue(bundle.exists())
        keep.unlink()
        maintenance.cleanup(results, False)
        self.assertFalse(bundle.exists())
        self.assertEqual((staged / 'passed.xcresult/result').read_text(), 'passed result')
        self.assertIsNone(maintenance.artifact_path(str(results), results.resolve()))
        self.assertIsNone(maintenance.artifact_path(str(results.resolve()), results))
        orphan = results / 'raw/orphan.log'
        orphan.parent.mkdir()
        orphan.write_text('crashed run')
        os.utime(orphan, (0, 0))
        pin = retention.marker(orphan, retention.KEEP)
        pin.touch()
        maintenance.cleanup(results, False)
        self.assertTrue(orphan.exists())
        pin.unlink()
        maintenance.cleanup(results, False)
        self.assertFalse(orphan.exists())

    def test_guidance_receipts_only_expire_for_this_repository(self):
        owned = self.output('receipts/trinket-agent-owned.json', content=json.dumps({'root': str(self.root.resolve())}))
        other = self.output('receipts/trinket-agent-other.json', content=json.dumps({'root': str(self.root.parent)}))
        self.clean()
        self.assertFalse(owned.exists())
        self.assertTrue(other.exists())

    def test_shell_lifecycle_keeps_exit_code_and_finishes_after_consumers(self):
        root = self.make_repo_fixture(str(self.root), ('Scripts/lib/output-retention.sh',))
        for status in (0, 7):
            path = root / f'.DerivedData/HandoffResults/case-{status}'
            command = '''source Scripts/lib/output-retention.sh
mkdir -p "$1"
trinket_output_retention_begin "$1"
echo complete > "$1/output.log"
test -f "$1/output.log"
exit "$2"
'''
            result = subprocess.run(['bash', '-c', command, '_', str(path), str(status)], cwd=root,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, status, result.stdout + result.stderr)
            self.assertEqual(path.exists(), status != 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
