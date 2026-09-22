"""Build identity and CI transfer contracts, using fake toolchains and products."""

SCRIPT_INPUTS = (
    'Scripts/build-metadata.py',
    'Scripts/build-freshness.sh',
    'Scripts/build-for-testing.sh',
    'Scripts/build.sh',
    'Scripts/run-simulator.sh',
    'Scripts/test.sh',
    'Scripts/test-package.sh',
    'Scripts/lib/test-helpers.sh',
    'Scripts/restore-ci-test-products.sh',
    'Scripts/stage-ci-test-artifact.sh',
)

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def fake_toolchain(root):
    """Provide stable identities without requiring Xcode or a Git checkout."""
    tools = root / 'fake-tools'
    tools.mkdir()
    for name, body in {
        'xcodebuild': 'echo "${FAKE_XCODE:-Xcode fixture A}"',
        'xcrun': 'echo "${FAKE_SDK:-SDK fixture A}"',
        'git': 'if [ "$1" = rev-parse ]; then echo "${FAKE_COMMIT:-commit-a}"; fi',
    }.items():
        executable = tools / name
        executable.write_text('#!/bin/sh\n' + body + '\n')
        executable.chmod(0o755)
    return {**os.environ, 'PATH': f'{tools}:{os.environ["PATH"]}',
            'CI': '', 'GITHUB_ACTIONS': ''}


class BuildMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        scripts = self.root / 'Scripts'
        scripts.mkdir()
        for name in ('build-metadata.py', 'build-freshness.sh', 'build-inputs.env',
                     'restore-ci-test-products.sh', 'stage-ci-test-artifact.sh'):
            shutil.copy2(ROOT / 'Scripts' / name, scripts)
        self.env = fake_toolchain(self.root)

    def shell(self, command, expected=0, env=None):
        result = subprocess.run(['bash', '-ec', 'source Scripts/build-freshness.sh\n' + command],
                                cwd=self.root, env=env or self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def build(self, fingerprint='smoke', env=None):
        self.shell(f'begin_build_stamps results {fingerprint}\ntouch_build_stamp results {fingerprint}', env=env)

    def check(self, fingerprint='smoke', expected=0, env=None):
        return self.shell(f'assert_no_build_inputs_are_fresh "$(build_stamp_path results {fingerprint})" {fingerprint}',
                          expected, env)

    def metadata(self):
        return next((self.root / 'results').glob('*.stamp.json'))

    def test_matching_identity_and_local_source_guard(self):
        self.build()
        self.check()
        self.check(env={**self.env, 'FAKE_COMMIT': 'commit-b'})
        source = self.root / 'Trinket/App.swift'
        source.parent.mkdir()
        source.write_text('changed')
        stamp = next((self.root / 'results').glob('*.stamp'))
        os.utime(source, (stamp.stat().st_mtime + 2,) * 2)
        self.assertIn('Trinket/App.swift', self.check(expected=1).stderr)

    def test_xcode_sdk_configuration_architecture_and_fingerprint_mismatches(self):
        for variable in ('FAKE_XCODE', 'FAKE_SDK'):
            with self.subTest(variable=variable):
                self.build()
                self.assertIn('mismatch', self.check(expected=1, env={**self.env, variable: 'different'}).stderr)
        for key in ('configuration', 'host_architecture', 'architecture_policy', 'fingerprint', 'version'):
            with self.subTest(key=key):
                self.build()
                path = self.metadata()
                data = json.loads(path.read_text())
                data[key] = 'incompatible'
                path.write_text(json.dumps(data))
                self.assertIn(key, self.check(expected=1).stderr)

    def test_legacy_missing_and_corrupt_metadata_fail_closed(self):
        self.check(expected=1)
        for content in (None, '{', '[]'):
            self.build()
            path = self.metadata()
            if content is None:
                path.unlink()
            else:
                path.write_text(content)
            self.check(expected=1)

    def test_ci_requires_stamp_and_commit(self):
        ci = {**self.env, 'CI': 'true'}
        self.check(expected=1, env=ci)
        self.build(env=ci)
        self.check(env=ci)
        self.assertIn('commit', self.check(expected=1, env={**ci, 'FAKE_COMMIT': 'commit-b'}).stderr)

    def test_begin_invalidates_family_without_invalidating_other_packages(self):
        self.build('package_TrinketCore')
        self.build('smoke')
        self.shell('begin_build_stamps results ui\nexit 65', expected=65)
        self.check(expected=1)
        self.check('package_TrinketCore')
        self.build('package_BattleEngine')
        self.shell('begin_build_stamps results package_TrinketCore\nexit 65', expected=65)
        self.check('package_TrinketCore', expected=1)
        self.check('package_BattleEngine')

    def test_toolchain_change_during_build_cannot_stamp(self):
        self.shell('begin_build_stamps results smoke\nexport FAKE_XCODE=changed\ntouch_build_stamp results smoke', expected=1)
        self.check(expected=1)

    def make_products(self, env):
        products = self.root / '.DerivedData/Build/Products'
        app = products / 'Debug-iphonesimulator/Trinket.app/Trinket'
        app.parent.mkdir(parents=True, exist_ok=True)
        app.write_text('binary')
        app.chmod(0o755)
        (products / 'Trinket.xctestrun').write_text('test configuration')
        self.shell('begin_build_stamps .DerivedData/TestResults smoke\n'
                   'touch_build_stamp .DerivedData/TestResults smoke\n'
                   'touch_build_stamp .DerivedData/TestResults ui', env=env)

    def prepare(self, env, downloaded=True, status=0, expected=0, valid=True):
        rebuild = self.root / 'rebuild.sh'
        rebuild.write_text('#!/bin/bash\nset -euo pipefail\necho rebuilt >> rebuild-count\n'
                           f'exit_status={status}\n(( exit_status == 0 )) || exit "$exit_status"\n'
                           'mkdir -p .DerivedData/Build/Products/Debug-iphonesimulator/Trinket.app\n'
                           'touch .DerivedData/Build/Products/Trinket.xctestrun\n'
                           + ('source Scripts/build-freshness.sh\n'
                              'begin_build_stamps .DerivedData/TestResults smoke\n'
                              'touch_build_stamp .DerivedData/TestResults smoke\n'
                              'touch_build_stamp .DerivedData/TestResults ui\n' if valid else ''))
        rebuild.chmod(0o755)
        return self.shell('./Scripts/restore-ci-test-products.sh '
                          + ('--downloaded ' if downloaded else '') + '-- ./rebuild.sh', expected, env)

    def test_ci_transfer_reuses_matching_and_rebuilds_wrong_commit_or_toolchain(self):
        ci = {**self.env, 'CI': 'true'}
        self.make_products(ci)
        products = self.root / '.DerivedData/Build/Products'
        (products / 'current-app').symlink_to('Debug-iphonesimulator/Trinket.app')
        self.shell('./Scripts/stage-ci-test-artifact.sh', env=ci)
        self.prepare(ci)
        self.assertFalse((self.root / 'rebuild-count').exists())
        self.assertTrue((products / 'current-app').is_symlink())
        self.assertTrue(os.access(products / 'Debug-iphonesimulator/Trinket.app/Trinket', os.X_OK))
        for variable in ('FAKE_COMMIT', 'FAKE_XCODE', 'FAKE_SDK'):
            self.prepare({**ci, variable: 'different'})
            self.assertFalse((products / 'current-app').exists())
        self.assertEqual((self.root / 'rebuild-count').read_text().splitlines(), ['rebuilt'] * 3)

    def test_ci_missing_corrupt_or_legacy_transfer_rebuilds_and_checks_replacement(self):
        ci = {**self.env, 'CI': 'true'}
        self.prepare(ci, downloaded=False)
        archive = self.root / '.DerivedData/ci-test-artifact.tar'
        archive.write_text('broken tar')
        self.prepare(ci)
        for path in (self.root / '.DerivedData/TestResults').glob('*.json'):
            path.unlink()
        self.shell('./Scripts/stage-ci-test-artifact.sh', env=ci)
        self.prepare(ci)
        self.prepare(ci, downloaded=False, valid=False, expected=1)
        self.prepare(ci, downloaded=False, status=65, expected=65)
        self.assertFalse(list((self.root / '.DerivedData/TestResults').glob('*.stamp')))


if __name__ == '__main__':
    unittest.main()
