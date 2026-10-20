"""Prevent runner image changes or a failed Metal install from passing setup."""
from pathlib import Path
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import load_script

SETUP = load_script('ci_xcode_setup', 'setup-ci-xcode.py')


class CIXcodeTests(unittest.TestCase):
    def test_image_rollout_selects_exact_product_build_and_latest_independently(self):
        with tempfile.TemporaryDirectory() as temporary:
            apps = Path(temporary)
            for name, version, build in [('Xcode_27.app', '27.0', '27A266a'),
                                         ('Xcode_27.1.app', '27.1', '27A9269'),
                                         ('Xcode_beta.app', '27.2', '27B5028f')]:
                contents = apps / name / 'Contents'
                contents.mkdir(parents=True)
                with (contents / 'version.plist').open('wb') as output:
                    plistlib.dump(dict(CFBundleShortVersionString=version, ProductBuildVersion=build), output)
                with (contents / 'Info.plist').open('wb') as output:
                    plistlib.dump(dict(DTXcodeBuild='wrong-build'), output)
            (apps / 'Xcode.app').symlink_to(apps / 'Xcode_27.1.app')
            installations = SETUP.installed_xcodes(apps)
            self.assertEqual(len(installations), 3)
            pin = dict(version='27.1', build='27A9269')
            self.assertEqual(SETUP.select_xcode(installations, 'verified', pin)[1:], ('27.1', '27A9269'))
            self.assertEqual(SETUP.select_xcode(installations, 'latest', pin)[1:], ('27.2', '27B5028f'))
            with self.assertRaisesRegex(RuntimeError, 'No qualified Xcode'):
                SETUP.select_xcode(installations, 'verified', dict(version='27.2', build='27B5019j'))

    def test_rollout_uses_only_qualified_identities_and_prefers_the_primary_build(self):
        previous = (Path('/Applications/Previous.app'), '27.1', '27A9269')
        preferred = (Path('/Applications/Preferred.app'), '27.1', '27A9275')
        unqualified = (Path('/Applications/Beta.app'), '27.2', '27B5028f')
        pin = dict(version='27.1', build='27A9275', qualified_builds=[
            dict(version='27.1', build='27A9269'), dict(version='27.1', build='27A9275')])
        self.assertEqual(SETUP.select_xcode([previous, unqualified], 'verified', pin), previous)
        self.assertEqual(SETUP.select_xcode([preferred, unqualified], 'verified', pin), preferred)
        self.assertEqual(SETUP.select_xcode([previous, preferred], 'verified', pin), preferred)
        self.assertEqual(SETUP.select_xcode([previous, unqualified], 'latest', pin), unqualified)
        with self.assertRaisesRegex(RuntimeError, 'No qualified Xcode'):
            SETUP.select_xcode([unqualified], 'verified', pin)
        with self.assertRaisesRegex(RuntimeError, 'No qualified Xcode'):
            SETUP.select_xcode([(preferred[0], '27.2', preferred[2])], 'verified', pin)
        for entries in ([], [pin, pin], [dict(version='27.1', build='27A9269')]):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                SETUP.select_xcode([preferred], 'verified', {**pin, 'qualified_builds': entries})

    def test_explicit_candidate_never_falls_back_or_overrides_verified_pin(self):
        installations = [(Path('/Applications/RC.app'), '27.1', '27A9275'),
                         (Path('/Applications/Beta.app'), '27.2', '27B5028f')]
        pin = dict(version='27.1', build='27A9269')
        self.assertEqual(SETUP.select_xcode(installations, 'latest', pin, '27A9275'), installations[0])
        with self.assertRaisesRegex(RuntimeError, 'not installed'):
            SETUP.select_xcode(installations[1:], 'latest', pin, '27A9275')
        with self.assertRaisesRegex(RuntimeError, 'latest validation channel'):
            SETUP.select_xcode(installations, 'verified', pin, '27A9275')
        with self.assertRaisesRegex(RuntimeError, 'Invalid'):
            SETUP.select_xcode(installations, 'latest', pin, '../RC.app')

    def test_native_activation_is_bound_to_the_qualified_build_and_package(self):
        pin = dict(version='27.1', build='27A9275', qualified_builds=[
            dict(version='27.1', build='27A9275', native_packages=['BattleEngine', 'TrinketCore', 'TrinketContent']),
            dict(version='27.1', build='27A9269')])
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Scripts/config').mkdir(parents=True)
            (root / 'Scripts/config/ci-xcode.json').write_text(json.dumps(pin))
            for version, build, expected in [('27.1', '27A9275', 'BattleEngine TrinketCore TrinketContent'),
                                              ('27.1', '27A9269', 'BattleEngine TrinketCore'),
                                              ('27.2', '27B5028f', '')]:
                output = root / 'environment'
                output.write_text('')
                with self.subTest(build=build), patch.object(SETUP, 'ROOT', root), \
                        patch.object(SETUP, 'installed_xcodes', return_value=[(root / 'Xcode.app', version, build)]), \
                        patch.object(SETUP.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), \
                        patch.dict(os.environ, GITHUB_ENV=str(output), GITHUB_STEP_SUMMARY=''), \
                        patch.object(sys, 'argv', ['setup-ci-xcode.py', '--channel', 'latest']):
                    SETUP.main()
                exported = dict(line.split('=', 1) for line in output.read_text().splitlines())
                self.assertEqual(exported['XCODE_BUILD'], build)
                self.assertEqual(exported['TRINKET_CI_NATIVE_PACKAGES'], expected)
        for packages in (['TrinketPersistence'], ['TrinketCore', 'TrinketCore'], 'TrinketContent'):
            with self.subTest(packages=packages), self.assertRaises(ValueError):
                SETUP.native_packages(dict(version='27.1', build='27A9275', native_packages=packages),
                                      '27.1', '27A9275')

    def test_metal_retry_requires_real_readiness_and_never_accepts_download_exit_alone(self):
        environment = dict(DEVELOPER_DIR='/Applications/Selected.app/Contents/Developer')
        for download_failure in (subprocess.CompletedProcess([], 70), subprocess.TimeoutExpired('download', 120)):
            with self.subTest(failure=download_failure), patch.object(SETUP, 'metal_probe', side_effect=[False, True]) as probe, \
                    patch.object(SETUP.subprocess, 'run', side_effect=[download_failure, subprocess.CompletedProcess([], 0)]) as run, \
                    patch.object(SETUP.time, 'sleep') as sleep:
                SETUP.ensure_metal(environment)
                self.assertEqual(probe.call_count, 2)
                self.assertEqual(run.call_count, 2)
                self.assertEqual(run.call_args.args[0], ['xcodebuild', '-downloadComponent', 'MetalToolchain'])
                self.assertEqual(run.call_args.kwargs['env'], environment)
                sleep.assert_called_once_with(10)
        with patch.object(SETUP, 'metal_probe', return_value=False), \
                patch.object(SETUP.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run, \
                patch.object(SETUP.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'after three attempts'):
                SETUP.ensure_metal(environment)
            self.assertEqual(run.call_count, 3)

    def test_metal_probe_checks_compilation_and_linking_with_selected_sdk(self):
        environment = dict(DEVELOPER_DIR='/selected')
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            def compiler(command, **kwargs):
                self.assertEqual(command[:3], ['xcrun', '--sdk', 'iphonesimulator'])
                self.assertEqual(kwargs['env'], environment)
                if command[3] == 'metallib':
                    Path(command[-1]).touch()
                return subprocess.CompletedProcess(command, 0)
            with patch.object(SETUP.subprocess, 'run', side_effect=compiler):
                self.assertTrue(SETUP.metal_probe(environment, directory))
            # An existing library cannot hide a subsequent compiler failure.
            with patch.object(SETUP.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
                self.assertFalse(SETUP.metal_probe(environment, directory))


if __name__ == '__main__':
    unittest.main()
