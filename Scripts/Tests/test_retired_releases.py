"""Superseded releases expire without sacrificing current or unfinished runs."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from internal import retired_releases as retire
from internal import output_retention as retention


class RetiredReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = self.root / 'store'
        self.state = self.root / '.DerivedData/testflight'
        self.state.mkdir(parents=True)
        self.patches = [patch.object(retire, 'worktree_roots', return_value=(self.root,)),
                        patch.object(retention, 'process_snapshot', return_value={}),
                        patch.object(retire.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 1, '', ''))]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def release(self, build, stage):
        run = self.state / str(build)
        run.mkdir()
        archive = run / 'Trinket.xcarchive'
        archive.mkdir()
        (archive / 'binary').write_text('build')
        backup = self.artifacts / 'releases' / str(build).zfill(64)
        backup.mkdir(parents=True)
        (backup / 'Trinket.ipa').write_text('ipa')
        receipt = {'schema': 1, 'stage': stage, 'build': build, 'bundle_id': 'game', 'version': '1',
                   'archive': str(archive), 'symbol_artifacts': {'status': 'verified', 'path': str(backup)}}
        (run / 'receipt.json').write_text(json.dumps(receipt))
        return run, archive, backup

    def test_only_superseded_ready_artifacts_expire(self):
        old, archive, backup = self.release(1, 'ready')
        _, current, current_backup = self.release(3, 'ready')
        _, pending, pending_backup = self.release(2, 'uploading')
        self.assertEqual(retire.cleanup(self.root, apply=False, artifact_root=self.artifacts)[0], 2)
        self.assertTrue(archive.exists())
        self.assertEqual(retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)[0], 2)
        self.assertFalse(archive.exists())
        self.assertFalse((backup / 'Trinket.ipa').exists())
        self.assertTrue((old / 'receipt.json').exists())
        self.assertTrue((old / 'artifact-expiry.jsonl').exists())
        self.assertTrue(current.exists() and current_backup.exists() and pending.exists() and pending_backup.exists())

    def test_old_attempts_retire_but_unknown_content_stays(self):
        run, _, _ = self.release(1, 'ready')
        self.release(2, 'ready')
        attempt = run / 'artifacts-a1b2'
        archive = attempt / 'Trinket.xcarchive'
        archive.mkdir(parents=True)
        (archive / 'binary').write_text('old attempt')
        export = attempt / 'export/Trinket.ipa'
        export.parent.mkdir()
        export.write_text('old attempt')
        unknown = attempt / 'notes.txt'
        unknown.write_text('keep')
        self.assertEqual(retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)[0], 4)
        self.assertFalse(archive.exists() or export.exists())
        self.assertTrue(unknown.exists())

    def test_unfinished_run_can_reference_an_old_working_copy(self):
        _, archive, _ = self.release(1, 'ready')
        self.release(3, 'ready')
        pending, _, _ = self.release(2, 'uploading')
        path = pending / 'receipt.json'
        receipt = json.loads(path.read_text())
        receipt['archive'] = str(archive)
        path.write_text(json.dumps(receipt))
        retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)
        self.assertTrue(archive.exists())

    def test_newer_version_supersedes_even_with_lower_build_number(self):
        old, archive, _ = self.release(8, 'ready')
        current, _, _ = self.release(1, 'ready')
        path = current / 'receipt.json'
        receipt = json.loads(path.read_text())
        receipt['version'] = '2.0'
        path.write_text(json.dumps(receipt))
        self.assertEqual(retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)[0], 2)
        self.assertFalse(archive.exists())
        self.assertTrue((old / 'receipt.json').exists())

    def test_keep_marker_and_unfinished_shared_backup_are_protected(self):
        old, archive, backup = self.release(1, 'ready')
        self.release(3, 'ready')
        pending, _, _ = self.release(2, 'uploading')
        path = pending / 'receipt.json'
        receipt = json.loads(path.read_text())
        receipt['symbol_artifacts']['path'] = str(backup)
        path.write_text(json.dumps(receipt))
        (old / '.retention-keep').touch()
        self.assertEqual(retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)[0], 0)
        self.assertTrue(archive.exists() and (backup / 'Trinket.ipa').exists())

    def test_unknown_receipt_and_open_file_fail_closed(self):
        _, archive, _ = self.release(1, 'ready')
        self.release(2, 'ready')
        bad = self.state / 'unknown'
        bad.mkdir()
        (bad / 'receipt.json').write_text('{}')
        with self.assertRaises(ValueError):
            retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)
        (bad / 'receipt.json').unlink()
        with patch.object(retire.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 0, 'open', '')):
            self.assertEqual(retire.cleanup(self.root, apply=True, artifact_root=self.artifacts)[0], 0)
        self.assertTrue(archive.exists())

if __name__ == '__main__':
    unittest.main()
