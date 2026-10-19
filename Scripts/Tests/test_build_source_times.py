"""Warm build inputs must retain timestamps only when their bytes still match."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from script_test_support import ROOT, load_script

TIMES = load_script('build_source_times_test', 'build-source-times.py')


class BuildSourceTimesTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'Trinket/App.swift'
        source.parent.mkdir(parents=True)
        source.write_text('let value = 1\n')
        changed = root / 'Trinket/Changed.swift'
        changed.write_text('let value = 1\n')
        subprocess.run(['git', 'init', '-q', str(root)], check=True)
        subprocess.run(['git', '-C', str(root), 'add', 'Trinket'], check=True)
        for path in (source, changed):
            os.utime(path, ns=(1700000000000000000, 1700000000000000000))
        return source, changed

    def test_unchanged_checkout_reuses_times_while_equal_size_changes_and_new_files_stay_fresh(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, changed = self.fixture(root)
            TIMES.process(root, 'record')
            changed.write_text('let value = 2\n')
            fresh = 1700000010000000000
            for path in (source, changed):
                os.utime(path, ns=(fresh, fresh))
            added = root / 'Trinket/Added.swift'
            added.write_text('let new = 1')
            subprocess.run(['git', '-C', str(root), 'add', str(added)], check=True)
            added_time = added.stat().st_mtime_ns
            self.assertEqual(TIMES.process(root, 'restore'), 1)
            self.assertEqual(source.stat().st_mtime_ns, 1700000000000000000)
            self.assertEqual(changed.stat().st_mtime_ns, fresh)
            self.assertEqual(changed.read_text(), 'let value = 2\n')
            self.assertEqual(added.stat().st_mtime_ns, added_time)

    def test_missing_corrupt_foreign_and_escape_metadata_never_changes_other_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, changed = self.fixture(root)
            self.assertEqual(TIMES.process(root, 'restore'), 0)
            TIMES.process(root, 'record')
            state = root / '.DerivedData/build-source-times.json'
            saved = json.loads(state.read_text())
            fresh = 1700000010000000000
            for payload in ('broken', [], {**saved, 'context': {'root': 'other-checkout'}},
                            {**saved, 'files': {'../outside': saved['files']['Trinket/App.swift']}}):
                os.utime(source, ns=(fresh, fresh))
                state.write_text(payload if isinstance(payload, str) else json.dumps(payload))
                self.assertEqual(TIMES.process(root, 'restore'), 0)
                self.assertEqual(source.stat().st_mtime_ns, fresh)
            state.write_text(json.dumps(saved))
            changed.unlink()
            # A tracked input replaced with a symlink must not touch its target.
            target = root / 'outside.swift'
            target.write_text(source.read_text())
            os.utime(target, ns=(fresh, fresh))
            source.unlink()
            source.symlink_to(target)
            self.assertEqual(TIMES.process(root, 'restore'), 0)
            self.assertEqual(target.stat().st_mtime_ns, fresh)

    def test_ci_restores_before_build_and_records_before_cache_save(self):
        action = (ROOT / '.github/actions/restore-and-build/action.yml').read_text()
        self.assertLess(action.index('build-source-times.py restore'), action.index('run: ${{ inputs.build-command }}'))
        self.assertLess(action.index('run: ${{ inputs.build-command }}'), action.index('build-source-times.py record'))
        self.assertLess(action.index('build-source-times.py record'), action.index('- name: Save warm build cache'))


if __name__ == '__main__':
    unittest.main()
