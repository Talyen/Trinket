"""Generated records expire without touching live, modified or caller-owned data."""
from contextlib import nullcontext
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from script_test_support import ROOT
from internal import diagnostic_retention as policy
from internal import output_retention as retention


class DiagnosticRetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = time.time()
        self.records = []
        self.addCleanup(patch.stopall)
        patch.object(retention, 'process_snapshot', return_value={}).start()
        patch.object(retention, 'primary_worktree_root', side_effect=lambda p: p).start()
        patch.object(retention, 'legacy_runtime_owner', return_value=None).start()

    def bundle(self, name, age, extra=None):
        base = self.root / name
        result = base / 'test.xcresult'
        result.mkdir(parents=True)
        (result / 'Info.plist').write_text('generated result')
        if extra:
            target = result / extra
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('protected')
        for file in result.rglob('*'):
            os.utime(file, (self.now - age,) * 2)
        record = policy.seal(base, [str(p.relative_to(base)) for p in base.rglob('*') if p.is_file()], now=self.now - age)
        self.records.append((base, record))
        return result

    def test_age_size_latest_and_dry_run_match_apply(self):
        old = self.bundle('old', 2 * policy.DAY)
        latest = self.bundle('latest', 100)
        self.assertEqual(policy.expire(self.records, self.root, now=self.now, inactive=lambda p: True), [])
        preview = policy.expire(self.records, self.root, now=self.now, budget=1, inactive=lambda p: True)
        self.assertEqual([x['path'] for x in preview], [str(old)])
        self.assertTrue(old.exists())
        actual = policy.expire(self.records, self.root, apply=True, now=self.now, budget=1, inactive=lambda p: True)
        self.assertEqual([x['path'] for x in actual], [str(old)])
        self.assertFalse(old.exists())
        self.assertTrue(latest.exists())

    def test_changed_kept_locked_and_open_records_stay(self):
        changed = self.bundle('changed', 4 * policy.DAY)
        (changed / 'Info.plist').write_text('updated data')
        kept = self.bundle('kept', 4 * policy.DAY)
        (kept / '.retention-keep').touch()
        owned = self.bundle('owned', 4 * policy.DAY)
        (owned / '.retention-owner.json').write_text('unknown owner')
        self.bundle('latest', 100)
        self.assertEqual(policy.expire(self.records, self.root, apply=True, now=self.now, inactive=lambda p: False), [])
        self.assertEqual(policy.expire(self.records, self.root, apply=True, now=self.now, inactive=lambda p: True), [])
        self.assertTrue(all(p.exists() for p in (changed, kept, owned)))

    def test_protected_payloads_and_links_are_not_sealed(self):
        for index, file in enumerate(['saves/player.json', 'source/card.swift', 'art/original.png', 'capture.mp4', 'build.ipa', 'PlayerSave.sqlite', 'output.lock']):
            self.bundle(str(index), 4 * policy.DAY, file)
            self.assertEqual(self.records[-1][1]['entries'], [])
        linked = self.root / 'link.log'
        linked.symlink_to(self.root / '0/test.xcresult/Info.plist')
        self.assertEqual(policy.seal(self.root, ['link.log'])['entries'], [])

    def test_unsealed_legacy_and_recent_output_are_not_deleted(self):
        old = self.bundle('old', 4 * policy.DAY)
        self.records[0] = (self.records[0][0], {})
        recent = self.bundle('recent', policy.DAY / 2)
        self.bundle('latest', 1)
        self.assertEqual(policy.expire(self.records, self.root, apply=True, now=self.now, budget=1, inactive=lambda p: True), [])
        self.assertTrue(old.exists() and recent.exists())

    def test_active_lifecycle_lock_blocks_removal(self):
        old = self.bundle('old', 4 * policy.DAY)
        self.bundle('latest', 100)
        with patch.object(retention, 'lifecycle_guard', return_value=nullcontext(False)):
            self.assertEqual(policy.expire(self.records, self.root, apply=True, now=self.now, inactive=lambda p: True), [])
        self.assertTrue(old.exists())

    def test_producer_seals_only_new_generated_artifacts_and_preserves_unknown_controls(self):
        old = self.bundle('producer', 5 * policy.DAY)
        base = old.parent
        fresh = base / 'fresh.log'
        fresh.write_text('new failed invocation log')
        policy.seal_completed_results(base, self.now - 100)
        record = json.loads((base / '.retention-diagnostics.json').read_text())
        self.assertEqual([e['path'] for e in record['entries']], ['fresh.log'])
        control = base / '.retention-diagnostics.json'
        control.write_text('caller-owned metadata')
        policy.seal_completed_results(base, self.now - 100)
        self.assertEqual(control.read_text(), 'caller-owned metadata')

    def test_change_during_last_activity_check_preserves_new_data(self):
        old = self.bundle('old', 4 * policy.DAY)
        self.bundle('latest', 1)
        calls = 0
        def inactive(target):
            nonlocal calls
            calls += 1
            if calls == 2:
                (target / 'new.log').write_text('new data')
            return True
        self.assertEqual(policy.expire(self.records, self.root, apply=True, now=self.now, inactive=inactive), [])
        self.assertTrue((old / 'new.log').exists())

    def test_completed_xcode_invocations_have_independent_seals_but_custom_paths_do_not(self):
        base = self.root / '.DerivedData/TestResults'
        for name in ('first', 'second'):
            result = base / (name + '.xcresult')
            result.mkdir(parents=True)
            (result / 'Info.plist').write_text('completed')
            log = base / 'raw' / (name + '.log')
            log.parent.mkdir(exist_ok=True)
            log.write_text('generated log')
            policy.seal_invocation(result, log, root=self.root)
        records = policy.result_records(base)
        self.assertEqual(len(records), 2)
        self.assertEqual({e['path'] for _, record in records for e in record['entries']}, {
            'first.xcresult', 'second.xcresult', 'raw/first.log', 'raw/second.log'})
        custom = self.root / 'custom/TestResults/third.xcresult'
        custom.mkdir(parents=True)
        (custom / 'Info.plist').write_text('caller-owned')
        policy.seal_invocation(custom, root=self.root)
        self.assertEqual(policy.result_records(custom.parent), [])
