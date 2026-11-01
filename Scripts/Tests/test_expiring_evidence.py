"""Evidence expiry preserves active, pinned and recently captured material."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

from internal import cli
from internal import expiring_evidence as expiry
from internal import output_retention as retention


class EvidenceExpiryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.common = self.root / '.git'
        self.common.mkdir()
        self.artifacts = self.root / 'artifacts'
        self.now = time.time()
        patches = [patch.object(cli, 'worktree_roots', return_value=(self.root,)),
                   patch.object(expiry, 'active_branches', return_value={'codex/active'}),
                   patch.object(expiry, 'shared_leases_busy', return_value=False),
                   patch.object(retention, 'process_snapshot', return_value={}),
                   patch.object(expiry.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 1, '', ''))]
        for item in patches:
            item.start()
            self.addCleanup(item.stop)

    def age(self, path):
        os.utime(path, (self.now - expiry.AGE * 2,) * 2)

    def snapshot(self, branch):
        snapshot = self.common / 'trinket-evidence/codex' / branch / 'abc-snapshot'
        target = snapshot / 'files/.DerivedData/Deliverables/Inspection/image.png'
        target.parent.mkdir(parents=True)
        target.write_text('pixels')
        manifest = snapshot / 'evidence.json'
        manifest.write_text(json.dumps({'branch': 'codex/' + branch, 'files': ['.DerivedData/Deliverables/Inspection/image.png']}))
        self.age(target)
        self.age(manifest)
        return target

    def cleanup(self, apply):
        return expiry.cleanup(self.root, self.common, apply=apply, now=self.now, artifact_root=self.artifacts)

    def test_inactive_profile_and_visual_expire_but_active_and_recent_stay(self):
        old = self.snapshot('finished')
        active = self.snapshot('active')
        profile = self.artifacts / 'profiles/device-old'
        profile.mkdir(parents=True)
        (profile / 'result.json').write_text('{}')
        trace = profile / 'recording.trace'
        trace.mkdir()
        (trace / 'data').write_text('trace')
        for path in (profile / 'result.json', trace, trace / 'data'):
            self.age(path)
        recent = self.root / '.DerivedData/VisualEvidence/recent.png'
        recent.parent.mkdir(parents=True)
        recent.write_text('recent')
        self.assertEqual(self.cleanup(False)[0], 2)
        self.assertTrue(trace.exists() and old.exists())
        self.assertEqual(self.cleanup(True)[0], 2)
        self.assertFalse(trace.exists() or old.exists())
        self.assertTrue((profile / 'result.json').exists() and active.exists() and recent.exists())
        self.assertTrue((old.parents[5] / 'visual-expiry.jsonl').exists())

    def test_snapshot_trace_is_retired_as_one_bundle_and_pins_are_honored(self):
        target = self.snapshot('finished')
        manifest = target.parents[4] / 'evidence.json'
        saved = json.loads(manifest.read_text())
        trace_name = '.DerivedData/Deliverables/device.trace'
        trace = manifest.parent / 'files' / trace_name
        trace.mkdir()
        (trace / 'data').write_text('trace')
        saved['files'].append(trace_name + '/data')
        manifest.write_text(json.dumps(saved))
        for path in (trace / 'data', trace, manifest):
            self.age(path)
        (trace / '.retention-keep').touch()
        self.assertEqual(self.cleanup(True)[0], 1)
        self.assertTrue(trace.exists())
        (trace / '.retention-keep').unlink()
        self.age(trace)
        self.assertEqual(self.cleanup(True)[0], 1)
        self.assertFalse(trace.exists())
        self.assertTrue((manifest.parent.parent / 'profile-expiry.jsonl').exists())

    def test_unpinned_legacy_trace_expires_but_other_investigation_files_stay(self):
        base = self.artifacts / 'profiles/old-investigation'
        trace = base / 'recording.trace'
        trace.mkdir(parents=True)
        (trace / 'data').write_text('trace')
        source = base / 'notes.swift'
        source.write_text('source')
        for path in (trace / 'data', trace):
            self.age(path)
        self.assertEqual(self.cleanup(True)[0], 1)
        self.assertFalse(trace.exists())
        self.assertTrue(source.exists())

    def test_snapshot_images_share_checks_and_preserve_native_bundles(self):
        first = self.snapshot('finished')
        manifest = first.parents[4] / 'evidence.json'
        saved = json.loads(manifest.read_text())
        targets = [first]
        for i in range(9):
            path = first.parent / f'image-{i}.png'
            path.write_text('pixels')
            self.age(path)
            targets.append(path)
            saved['files'].append(str(path.relative_to(manifest.parent / 'files')))
        native = manifest.parent / 'files/.DerivedData/Deliverables/Inspection/result.xcresult/image.png'
        native.parent.mkdir(parents=True)
        native.write_text('native result')
        self.age(native)
        saved['files'].append(str(native.relative_to(manifest.parent / 'files')))
        manifest.write_text(json.dumps(saved))
        self.age(manifest)
        with patch.object(expiry.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 1, '', '')) as opened:
            self.assertEqual(self.cleanup(True)[0], 10)
        self.assertEqual(opened.call_count, 3)
        self.assertTrue(all(not path.exists() for path in targets))
        self.assertTrue(native.exists())

    def test_open_file_or_new_active_branch_preserves_batch(self):
        target = self.snapshot('finished')
        with patch.object(expiry.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 0, 'open', '')):
            self.assertEqual(self.cleanup(True)[0], 0)
        with patch.object(expiry, 'active_branches', side_effect=[set(), {'codex/finished'}]):
            self.assertEqual(self.cleanup(True)[0], 0)
        self.assertTrue(target.exists())

    def test_keep_and_busy_producer_prevent_expiry(self):
        target = self.snapshot('finished')
        (target.parent / '.retention-keep').touch()
        profile = self.artifacts / 'profiles/device-old'
        profile.mkdir(parents=True)
        (profile / 'result.json').write_text('{}')
        trace = profile / 'recording.trace'
        trace.write_text('trace')
        self.age(profile / 'result.json')
        self.age(trace)
        with patch.object(expiry, 'shared_leases_busy', return_value=True):
            self.assertEqual(self.cleanup(True)[0], 0)
        self.assertTrue(target.exists() and trace.exists())

if __name__ == '__main__':
    unittest.main()
