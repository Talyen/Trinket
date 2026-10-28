"""Evidence storage maintenance preserves exact data and active work."""

import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import time
import unittest
from unittest import mock

from script_test_support import load_script

compact = load_script('evidence_compaction_test', 'compact-evidence.py')


@unittest.skipUnless(sys.platform == 'darwin', 'Filesystem compression and clones require macOS')
class EvidenceCompactionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.common = self.root / '.git'
        self.branch = self.common / 'trinket-evidence/codex/fixture'
        self.content = b'long repetitive diagnostic line\n' * 50000
        self.now = time.time()

    def report(self, snapshot, name='diagnostic.log'):
        base = self.branch / snapshot
        relative = '.DerivedData/Deliverables/' + name
        path = base / 'files' / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.content)
        os.utime(path, (self.now - 8 * 86400,) * 2)
        (base / 'evidence.json').write_text(json.dumps({'branch': 'codex/fixture', 'files': [relative]}))
        return path

    def test_compress_and_deduplicate_preserve_bytes_and_metadata(self):
        first, second = self.report('first'), self.report('second')
        os.utime(second, ns=(first.stat().st_atime_ns, first.stat().st_mtime_ns))
        before = first.stat().st_blocks * 512
        before_metadata = compact.metadata(first)
        with mock.patch.object(compact, 'active_branches', return_value=set()):
            changed, reduced = compact.compact(self.common, self.root, seconds=12, max_attempts=4)
        self.assertGreaterEqual(changed, 1)
        self.assertGreater(reduced, 0)
        self.assertLess(first.stat().st_blocks * 512, before)
        self.assertEqual(compact.metadata(first), before_metadata)
        self.assertEqual(first.read_bytes(), self.content)
        self.assertEqual(second.read_bytes(), self.content)
        second.write_bytes(b'changed independently')
        self.assertEqual(first.read_bytes(), self.content)

    def test_active_and_kept_evidence_is_not_replaced(self):
        report = self.report('first')
        identity = compact.identity(report)
        with mock.patch.object(compact, 'active_branches', return_value={'codex/fixture'}):
            self.assertEqual(compact.compact(self.common, self.root), (0, 0))
        (report.parent / '.retention-keep').touch()
        with mock.patch.object(compact, 'active_branches', return_value=set()):
            self.assertEqual(compact.compact(self.common, self.root), (0, 0))
        self.assertEqual(compact.identity(report), identity)

    def test_native_result_duplicates_are_cloned_without_transforming_contents(self):
        first = self.report('first', 'run.xcresult/Data/payload.bin')
        second = self.report('second', 'run.xcresult/Data/payload.bin')
        os.utime(second, ns=(first.stat().st_atime_ns, first.stat().st_mtime_ns))
        with mock.patch.object(compact, 'active_branches', return_value=set()):
            changed, _ = compact.compact(self.common, self.root, seconds=12, max_attempts=4)
        self.assertEqual(changed, 1)
        self.assertEqual(first.read_bytes(), self.content)
        self.assertEqual(second.read_bytes(), self.content)
        second.write_bytes(b'independent update')
        self.assertEqual(first.read_bytes(), self.content)

    def test_bounded_pass_resumes_and_still_finds_previous_snapshot(self):
        first = self.report('first', 'run.xcresult/Data/payload.bin')
        second = self.report('second', 'run.xcresult/Data/payload.bin')
        third = self.report('third', 'run.xcresult/Data/payload.bin')
        for path in (second, third):
            os.utime(path, ns=(first.stat().st_atime_ns, first.stat().st_mtime_ns))
        with mock.patch.object(compact, 'active_branches', return_value=set()):
            self.assertEqual(compact.compact(self.common, self.root, max_attempts=1)[0], 1)
            self.assertTrue((self.common / 'trinket-storage-maintenance/cursor.json').exists())
            self.assertEqual(compact.compact(self.common, self.root, max_attempts=1)[0], 1)
        self.assertEqual(third.read_bytes(), self.content)

    def test_bad_compressed_copy_never_replaces_evidence(self):
        report = self.report('first')
        identity = compact.identity(report)
        real_run = subprocess.run
        def run(command, *args, **kwargs):
            if command[0] == '/usr/bin/ditto':
                Path(command[-1]).write_bytes(b'corrupt')
                return subprocess.CompletedProcess(command, 0, b'', b'')
            return real_run(command, *args, **kwargs)
        with mock.patch.object(compact, 'active_branches', return_value=set()), \
             mock.patch.object(compact.subprocess, 'run', side_effect=run):
            self.assertEqual(compact.compact(self.common, self.root), (0, 0))
        self.assertEqual(compact.identity(report), identity)
        self.assertEqual(report.read_bytes(), self.content)


if __name__ == '__main__':
    unittest.main()
