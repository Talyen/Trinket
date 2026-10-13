"""Exercise deployment orchestration without credentials, Xcode, or Ruby gems."""

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',
    'Scripts/lib/output-retention.sh',
    'Gemfile',
    'Gemfile.lock',
    'Scripts/Tests/testflight_test.rb',
    'Scripts/config/testflight.example.json',
    'Scripts/internal/testflight.rb',
    'Scripts/internal/cli.py',
    'Scripts/lib/testflight-tools.sh',
    'Scripts/setup-testflight.sh',
    'Scripts/testflight.sh',
)


import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT


class TestFlightTests(unittest.TestCase):
    def environment(self):
        return {key: value for key, value in os.environ.items() if key != 'TRINKET_TESTFLIGHT_STATE_ROOT'}

    def test_deployment_contracts(self):
        ruby = shutil.which("ruby")
        self.assertIsNotNone(ruby, "Ruby is required for the credential-free TestFlight script regressions")
        result = subprocess.run(
            [ruby, str(ROOT / "Scripts/Tests/testflight_test.rb")],
            cwd=ROOT, env=self.environment(), capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("TestFlight regression scenarios passed", result.stdout)

    def test_deployment_wrapper_serializes_linked_worktrees(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'primary'
            root.mkdir()
            for relative in ('Scripts/testflight.sh', 'Scripts/internal/cli.py', 'Scripts/lib/lock.sh',
                             'Scripts/lib/output-retention.sh', 'Scripts/internal/output_retention.py',
                             'Scripts/cleanup-outputs.py'):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, target)
            (root / 'Scripts/lib/testflight-tools.sh').write_text(
                'trinket_testflight_tools() { TRINKET_BUNDLE="$PWD/bundle"; }\n'
            )
            bundle = root / 'bundle'
            bundle.write_text('#!/bin/bash\nprintf "started\\n"\nread -r release\n')
            bundle.chmod(0o755)
            (root / '.gitignore').write_text('.DerivedData/\n__pycache__/\n')
            linked = Path(directory) / 'linked checkout'
            environment = {key: value for key, value in self.environment().items()
                           if not key.startswith(('GIT_', 'TRINKET_'))}
            for command in (
                ['git', 'init', '-q', str(root)],
                ['git', '-C', str(root), 'add', '.'],
                ['git', '-C', str(root), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture'],
                ['git', '-C', str(root), 'worktree', 'add', '-qb', 'linked', str(linked)],
            ):
                subprocess.run(command, check=True, env=environment, capture_output=True)
            owner = subprocess.Popen(['bash', 'Scripts/testflight.sh'], cwd=linked, env=environment,
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.assertTrue(owner.stdout.readline().startswith('Command log: '))
                self.assertEqual(owner.stdout.readline(), 'started\n')
                other = subprocess.run(['bash', 'Scripts/testflight.sh'], cwd=root, env=environment,
                                       input='release\n', capture_output=True, text=True, timeout=15)
                self.assertNotEqual(other.returncode, 0, other.stdout + other.stderr)
                self.assertNotIn('started', other.stdout)
            finally:
                stdout, stderr = owner.communicate('release\n', timeout=15)
                self.assertEqual(owner.returncode, 0, stdout + stderr)
            self.assertFalse((root / '.DerivedData/testflight/.deploy.lock').exists())
            legacy = linked / '.DerivedData/testflight/.deploy.lock'
            legacy.mkdir(parents=True)
            (legacy / 'pid').write_text(str(os.getpid()))
            blocked = subprocess.run(['bash', 'Scripts/testflight.sh'], cwd=root, env=environment,
                                     input='release\n', capture_output=True, text=True, timeout=15)
            self.assertNotEqual(blocked.returncode, 0, blocked.stdout + blocked.stderr)
            self.assertIn('Legacy checkout-local deployment lock preserved', blocked.stderr)
            self.assertEqual((legacy / 'pid').read_text(), str(os.getpid()))

    @unittest.skipUnless((ROOT / ".tools/testflight/gems/bin/bundle").exists(),
                         "Optional pinned-Fastlane adapter check requires setup-testflight.sh")
    def test_installed_fastlane_adapter(self):
        result = subprocess.run(
            ["bash", "-c", 'source Scripts/lib/testflight-tools.sh\n'
             'trinket_testflight_tools "$PWD" false\n'
             '"$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/Tests/testflight_test.rb --fastlane'],
            cwd=ROOT, env=self.environment(), capture_output=True, text=True, timeout=45,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Pinned Fastlane adapter scenarios passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
