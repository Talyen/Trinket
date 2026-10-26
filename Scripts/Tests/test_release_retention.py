"""Release cleanup must leave complete, usable recovery evidence behind."""

from datetime import datetime, timezone
from contextlib import ExitStack
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
