"""Evidence inventory compares bytes and reports protections without mutation."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from script_test_support import load_script

report = load_script('evidence_audit_test', 'report-evidence.py')


class EvidenceAuditTests(unittest.TestCase):
    def test_duplicate_groups_include_protection_and_skip_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            common = root / '.git'
            branch = common / 'trinket-evidence/codex/fixture'
            files = []
            for name in ('first', 'second'):
                snapshot = branch / name
                file = snapshot / 'files/record.log'
                file.parent.mkdir(parents=True)
                file.write_bytes(b'equal evidence')
                (snapshot / 'evidence.json').write_text(json.dumps({'branch': 'codex/fixture', 'files': ['record.log']}))
                files.append(file)
            (branch / 'second/.retention-keep').touch()
            (branch / 'first/files/link').symlink_to(files[1])
            with mock.patch.object(report, 'active_branches', return_value={'codex/fixture'}):
                result = report.audit(common, root)
            group = next(g for g in result['duplicate_groups'] if g['bytes_per_file'] == len(b'equal evidence'))
            self.assertEqual(len(group['members']), 2)
            self.assertTrue(all('registered worktree' in m['protection'] for m in group['members']))
            self.assertTrue(any('keep marker' in m['protection'] for m in group['members']))
            self.assertTrue(any('non-regular' in i['reason'] for i in result['issues']))
            self.assertEqual([file.read_bytes() for file in files], [b'equal evidence'] * 2)

    def test_replaced_file_is_not_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'file'
            file.write_text('original')
            expected = report.identity(file.stat())
            file.unlink()
            file.write_text('replaced')
            with self.assertRaisesRegex(ValueError, 'changed before read'):
                report.digest(file, expected)
