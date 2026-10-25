"""Legacy export inventory must never mistake trace metadata for disposable data."""

from pathlib import Path
import tempfile
import unittest
from unittest import mock

from script_test_support import load_script

inventory = load_script('profile_inventory_test', 'report-profile-inventory.py')


class ProfileInventoryTests(unittest.TestCase):
    def test_large_exports_are_candidates_without_reading_or_deleting_capture_contents(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            capture = root / 'capture'
            trace = capture / 'recording.trace'
            trace.mkdir(parents=True)
            (trace / 'samples.xml').write_text('essential raw metadata')
            (capture / 'other.xml').write_text('unknown XML')
            (capture / 'result.json').write_text('identity must be verified separately')
            export = capture / 'swiftui.xml'
            with export.open('wb') as handle:
                handle.truncate(1024 ** 3)
            before = export.stat()
            with mock.patch.object(Path, 'open', side_effect=AssertionError('contents read')):
                report = inventory.inventory(root)
            self.assertEqual(report['eligibleForDeletionBytes'], 0)
            self.assertEqual({row['kind']: row['count'] for row in report['groups']},
                             {'derived-export-candidate': 1, 'raw-trace-component': 1, 'unknown-XML': 1})
            candidate = report['candidates'][0]
            self.assertEqual(candidate['logicalBytes'], 1024 ** 3)
            self.assertEqual(candidate['allocatedBytes'], before.st_blocks * 512)
            self.assertEqual(candidate['rawTraces'], ['capture/recording.trace'])
            self.assertEqual(candidate['provenance'], ['capture/result.json'])
            self.assertEqual(export.stat().st_mtime_ns, before.st_mtime_ns)

    def test_keeps_unknown_owners_and_ambiguous_trace_identity_stay_protected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'a.trace').mkdir()
            (root / 'b.trace').mkdir()
            (root / '.retention-keep').touch()
            (root / '.retention-owner.json').write_text('unreadable identity')
            (root / 'samples.xml').touch()
            candidate = inventory.inventory(root)['candidates'][0]
            self.assertIn('explicit keep', candidate['protection'])
            self.assertIn('owner record requires verification', candidate['protection'])
            self.assertIn('no unique adjacent raw trace', candidate['protection'])
            self.assertIn('no adjacent provenance record', candidate['protection'])

    def test_symlinks_are_skipped_and_symlink_roots_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory).resolve()
            root, foreign = base / 'profiles', base / 'foreign'
            root.mkdir()
            foreign.mkdir()
            (foreign / 'samples.xml').write_text('foreign capture')
            (root / 'linked').symlink_to(foreign, target_is_directory=True)
            (root / 'samples.xml').symlink_to(foreign / 'samples.xml')
            report = inventory.inventory(root)
            self.assertEqual(report['candidates'], [])
            self.assertEqual(set(report['skippedSymlinks']), {'linked', 'samples.xml'})
            with self.assertRaises(ValueError):
                inventory.inventory(root / 'linked')


if __name__ == '__main__':
    unittest.main()
