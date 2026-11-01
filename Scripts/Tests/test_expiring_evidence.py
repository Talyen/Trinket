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
