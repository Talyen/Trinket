"""Prevent runner image changes or a failed Metal install from passing setup."""
SCRIPT_INPUTS = (
    'Scripts/setup-ci-xcode.py', 'Scripts/config/ci-xcode.json',
    '.github/actions/setup-trinket/action.yml', '.github/workflows/gate.yml',
)

from pathlib import Path
import plistlib
import subprocess
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
            with self.assertRaisesRegex(RuntimeError, 'not installed'):
                SETUP.select_xcode(installations, 'verified', dict(version='27.2', build='27B5019j'))

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
