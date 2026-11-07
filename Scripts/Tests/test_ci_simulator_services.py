"""CI initializes its selected Xcode without changing a developer's Mac."""
from pathlib import Path
from contextlib import redirect_stdout, redirect_stderr
import io
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import ROOT

sys.path.insert(0, str(ROOT / 'Scripts'))
from internal import ci_simulator_services as SERVICES


class CISimulatorServicesTests(unittest.TestCase):
    def test_local_invocations_never_install_components_or_open_apps(self):
        with patch.object(SERVICES.subprocess, 'run') as run:
            SERVICES.prepare_components({'GITHUB_ACTIONS': 'false'})
            SERVICES.start_device_ui({'GITHUB_ACTIONS': 'false'})
        run.assert_not_called()

    def test_component_repair_uses_the_selected_xcode_and_checks_completion(self):
        environment = dict(GITHUB_ACTIONS='true', DEVELOPER_DIR='/Applications/Selected Xcode.app/Contents/Developer')
        for initial, count in [(0, 1), (1, 3)]:
            with self.subTest(initial=initial), patch.object(SERVICES.subprocess, 'run', side_effect=[
                    subprocess.CompletedProcess([], initial), subprocess.CompletedProcess([], 0),
                    subprocess.CompletedProcess([], 0)]) as run:
                SERVICES.prepare_components(environment)
                self.assertEqual(run.call_count, count)
                self.assertEqual(run.call_args_list[0].args[0], ['xcodebuild', '-checkFirstLaunchStatus'])
                if initial:
                    self.assertEqual(run.call_args_list[1].args[0], [
                        'sudo', 'env', 'DEVELOPER_DIR=' + environment['DEVELOPER_DIR'], 'xcodebuild', '-runFirstLaunch'])
                    self.assertTrue(run.call_args_list[-1].kwargs['check'])
                self.assertTrue(all(call.kwargs['env'] == environment for call in run.call_args_list))
                self.assertTrue(all(call.kwargs['timeout'] <= 180 for call in run.call_args_list))
        with patch.object(SERVICES.subprocess, 'run', side_effect=[subprocess.CompletedProcess([], 1),
                subprocess.CalledProcessError(1, 'first-launch')]), self.assertRaises(subprocess.CalledProcessError):
            SERVICES.prepare_components(environment)
        with self.assertRaisesRegex(ValueError, 'explicitly selected Xcode'):
            SERVICES.prepare_components({'GITHUB_ACTIONS': 'true'})

    def test_device_ui_belongs_to_selected_xcode_and_start_failure_is_not_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            developer = Path(directory) / 'Selected.app/Contents/Developer'
            environment = dict(GITHUB_ACTIONS='true', DEVELOPER_DIR=str(developer))
            app = developer.parent / 'Applications/DeviceHub.app'
            app.mkdir(parents=True)
            output, diagnostics = io.StringIO(), io.StringIO()
            with patch.object(SERVICES.subprocess, 'run') as run, \
                    redirect_stdout(output), redirect_stderr(diagnostics):
                SERVICES.start_device_ui(environment)
            self.assertEqual(output.getvalue(), '')
            self.assertIn('CI device services:', diagnostics.getvalue())
            run.assert_called_once_with(['open', '-g', '-j', '-a', str(app)], env=environment,
                                        timeout=30, check=True, stdout=diagnostics)
            with patch.object(SERVICES.subprocess, 'run', side_effect=subprocess.TimeoutExpired('open', 30)), \
                    self.assertRaises(subprocess.TimeoutExpired):
                SERVICES.start_device_ui(environment)
            app.rmdir()
            with self.assertRaisesRegex(ValueError, 'no device UI'):
                SERVICES.start_device_ui(environment)


if __name__ == '__main__':
    unittest.main()
