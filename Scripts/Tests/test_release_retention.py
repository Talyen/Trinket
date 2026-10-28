"""Release cleanup must leave complete, usable recovery evidence behind."""

from datetime import datetime, timezone
from contextlib import ExitStack
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest import mock
import zipfile

from internal import build_symbols as symbols
from internal import output_retention as retention
from internal import resource_lease
from internal import release_retention as releases
import test_build_symbols


class ReleaseRetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.context = ExitStack()
        self.addCleanup(self.context.close)
        self.root = Path(self.temp.name).resolve()
        self.now = time.time()
        self.run = self.root / '.DerivedData/testflight/run'
        self.artifacts = self.run / 'artifacts-fixture'
        self.artifacts.mkdir(parents=True)
        fixture = test_build_symbols.BuildSymbolTests()
        self.context.enter_context(mock.patch.object(symbols, 'uuids', fixture.identities))
        self.context.enter_context(mock.patch.object(symbols, 'artifact_root', return_value=self.root / 'durable'))
        self.context.enter_context(mock.patch.object(retention, 'process_snapshot', return_value={123: ('start', 'fixture')}))
        self.open_files = self.context.enter_context(mock.patch.object(releases.subprocess, 'run',
            return_value=subprocess.CompletedProcess('lsof', 1, '', '')))
        self.archive, _, _, self.ipa = fixture.fixture(self.artifacts)
        self.receipt = {'schema': 1, 'stage': 'ready', 'bundle_id': 'com.example.Trinket',
                        'version': '1.0', 'build': 7, 'commit': 'commit', 'xcode': 'Xcode fixture',
                        'archive': str(self.archive), 'ipa': str(self.ipa),
                        'ipa_sha256': symbols.digest(self.ipa)}
        self.receipt['symbol_artifacts'] = symbols.backup_archive(self.archive, self.ipa, self.receipt)
        self.extraction = self.artifacts / 'inspection'
        with zipfile.ZipFile(self.ipa) as zipped:
            zipped.extractall(self.extraction)
        self.receipt_path = self.run / 'receipt.json'
        self.save()
        for path in [*self.root.rglob('*'), self.root]:
            if path.is_file() or path.is_dir():
                os.utime(path, (self.now - 2 * releases.MAX_AGE,) * 2)

    def save(self):
        self.receipt_path.write_text(json.dumps(self.receipt))

    def clean(self, apply=True):
        return releases.cleanup(self.root, apply=apply, now=self.now, verbose=False)

    def test_recent_receipt_write_extends_grace_even_with_old_completion(self):
        self.receipt['completed_at'] = datetime.fromtimestamp(self.now - 3 * releases.MAX_AGE, timezone.utc).isoformat()
        self.save()
        self.assertEqual(self.clean()[0], 0)
        self.assertTrue(self.archive.exists())

    def test_bounded_pass_skips_already_retired_receipts(self):
        retired = self.run.parent / '00-already-retired'
        retired.mkdir()
        (retired / 'receipt.json').write_text(json.dumps(self.receipt))
        # Its paths belong to the actual fixture run, so this old receipt has no local duplicates.
        self.assertEqual(releases.cleanup(self.root, apply=False, now=self.now,
                                         verbose=False, max_verify=1)[0], 3)
        self.assertTrue(self.ipa.exists())

    def test_dry_run_apply_and_recovery_are_idempotent(self):
        self.assertEqual(self.clean(False)[0], 3)
        self.assertTrue(self.ipa.exists())
        self.assertEqual(self.clean()[0], 3)
        self.assertFalse(self.archive.exists())
        self.assertFalse(self.ipa.exists())
        self.assertFalse(self.extraction.exists())
        self.assertTrue(self.receipt_path.exists())
        preserved, _ = symbols.verified_release(self.receipt)
        self.assertTrue((preserved / 'Trinket.ipa').is_file())
        self.assertEqual(self.clean()[0], 0)

    def test_unrelated_scoped_producer_does_not_block_verified_release_duplicates(self):
        task = self.root / '.worktrees/other'
        task.mkdir(parents=True)
        (task / '.DerivedData').mkdir()
        data = {'version': 1, 'pid': 123, 'started': 'start', 'checkout': str(task),
                'paths': [[str(task), str(task)], [str(task / '.DerivedData'), str(task / '.DerivedData')]]}
        token = resource_lease.PREFIX + base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
        slot = self.root / '.DerivedData/.active-build/other.slot'
        slot.parent.mkdir(parents=True)
        slot.write_text(f'123 build {token}\n')
        with mock.patch.object(resource_lease, 'worktree_roots', return_value=(self.root, task)):
            self.assertEqual(self.clean(False)[0], 3)
            self.assertEqual(self.clean()[0], 3)
        self.assertTrue(self.receipt_path.exists())
        self.assertTrue(symbols.verified_release(self.receipt)[0].is_dir())

    def test_exported_working_copies_expire_only_with_verified_resume_backup(self):
        self.receipt['stage'] = 'exported'
        backup = self.receipt.pop('symbol_artifacts')
        self.save()
        os.utime(self.receipt_path, (self.now - 2 * releases.MAX_AGE,) * 2)
        self.assertEqual(self.clean()[0], 0)
        self.assertTrue(self.archive.exists())
        self.receipt['symbol_artifacts'] = backup
        self.save()
        os.utime(self.receipt_path, (self.now - 2 * releases.MAX_AGE,) * 2)
        self.assertEqual(self.clean()[0], 3)
        self.assertFalse(self.archive.exists())
        self.assertFalse(self.ipa.exists())
        retained, _ = symbols.verified_release(self.receipt)
        self.assertTrue((retained / 'Trinket.xcarchive').is_dir())
        self.assertTrue((retained / 'Trinket.ipa').is_file())
        self.assertEqual(json.loads(self.receipt_path.read_text())['stage'], 'exported')

    def test_interrupted_release_copy_remains_resumable_and_can_be_retired(self):
        self.receipt['stage'] = 'exported'
        self.save()
        os.utime(self.receipt_path, (self.now - 2 * releases.MAX_AGE,) * 2)
        with mock.patch.object(releases.shutil, 'rmtree', side_effect=SystemExit(143)):
            with self.assertRaises(SystemExit):
                releases.retire_working_copy(self.archive, self.run, 'archive', self.receipt, self.root)
        self.assertFalse(self.archive.exists())
        retained, _ = symbols.verified_release(self.receipt)
        self.assertTrue((retained / 'Trinket.xcarchive').is_dir())
        retired = next((self.run / '.retired-copies').iterdir())
        self.assertTrue((retired / 'contents').exists())
        for path in [retired, *retired.rglob('*')]:
            if not path.is_symlink():
                os.utime(path, (self.now - 2 * releases.MAX_AGE,) * 2)
        self.assertEqual(self.clean()[0], 3)
        self.assertFalse(retired.exists())

    def test_interrupted_release_copy_with_unexpected_evidence_is_preserved(self):
        self.receipt['stage'] = 'exported'
        self.save()
        os.utime(self.receipt_path, (self.now - 2 * releases.MAX_AGE,) * 2)
        with mock.patch.object(releases.shutil, 'rmtree', side_effect=SystemExit(143)):
            with self.assertRaises(SystemExit):
                releases.retire_working_copy(self.archive, self.run, 'archive', self.receipt, self.root)
        retired = next((self.run / '.retired-copies').iterdir())
        extra = retired / 'contents/unique-evidence'
        extra.write_text('preserve')
        for path in [retired, *retired.rglob('*')]:
            if not path.is_symlink():
                os.utime(path, (self.now - 2 * releases.MAX_AGE,) * 2)
        self.assertEqual(self.clean()[0], 2)
        self.assertEqual(extra.read_text(), 'preserve')

    def test_completion_grace_unknown_state_keep_and_busy_lock_protect_everything(self):
        for change in ('fresh', 'unfinished', 'keep', 'lock'):
            with self.subTest(change=change):
                if change == 'fresh':
                    self.receipt['completed_at'] = datetime.fromtimestamp(self.now - 86399, timezone.utc).isoformat()
                elif change == 'unfinished':
                    self.receipt['stage'] = 'uploaded'
                elif change == 'keep':
                    (self.extraction / retention.KEEP).touch()
                else:
                    (self.run.parent / '.deploy.lock').mkdir()
                self.save()
                os.utime(self.receipt_path, (self.now - 2 * releases.MAX_AGE,) * 2)
                if change == 'lock':
                    with self.assertRaisesRegex(ValueError, 'lock'):
                        self.clean()
                    (self.run.parent / '.deploy.lock').rmdir()
                else:
                    self.assertEqual(self.clean()[0], 0)
                self.assertTrue(self.ipa.exists())
                self.receipt.pop('completed_at', None)
                self.receipt['stage'] = 'ready'
                (self.extraction / retention.KEEP).unlink(missing_ok=True)

    def test_damaged_backup_and_unknown_open_files_never_authorize_deletion(self):
        preserved = Path(self.receipt['symbol_artifacts']['path'])
        target = preserved / 'Trinket.ipa'
        original = target.read_bytes()
        target.write_bytes(b'damaged')
        self.assertEqual(self.clean()[0], 0)
        target.write_bytes(original)
        self.open_files.return_value = subprocess.CompletedProcess('lsof', 2, '', 'unavailable')
        self.assertEqual(self.clean()[0], 0)
        self.assertTrue(self.archive.exists())
        self.assertTrue(self.ipa.exists())

    def test_changed_working_copy_is_preserved_instead_of_trusting_its_name(self):
        (self.extraction / 'unexpected-evidence').write_text('preserve this')
        for path in (self.extraction, self.extraction / 'unexpected-evidence'):
            os.utime(path, (self.now - 2 * releases.MAX_AGE,) * 2)
        self.assertEqual(self.clean()[0], 2)
        self.assertTrue(self.extraction.exists())

    def test_new_owner_between_verification_and_removal_protects_archive(self):
        verify = symbols.verified_release
        calls = 0
        def acquire(receipt):
            nonlocal calls
            result = verify(receipt)
            calls += 1
            if calls == 2:
                (self.archive / retention.OWNER).write_text('unknown owner acquired during verification')
            return result
        with mock.patch.object(symbols, 'verified_release', side_effect=acquire):
            self.clean()
        self.assertTrue(self.archive.exists())
        self.assertTrue((self.archive / retention.OWNER).exists())


if __name__ == '__main__':
    unittest.main()
