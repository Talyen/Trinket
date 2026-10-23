from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import load_script

MODULE = load_script('simulator_idle_cleanup', 'simulator-idle-cleanup.py')


class SimulatorIdleCleanupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.ui = {12: ('old start', '/Xcode.app/Contents/Applications/DeviceHub.app/Contents/MacOS/DeviceHub')}
        self.snapshot = {'session': [[12, 'old start'], [13, 'guest start']], 'ui': self.ui,
                         'guests': {}, 'reason': '', 'input_idle': 1000}
        self.previous = {'session': self.snapshot['session'], 'last_active': 1}
        self.human = {'name': 'Trinket Run', 'udid': 'human-device', 'state': 'Booted'}

    def run_cleanup(self, observations=None, inventory=None, previous=None, apply=True):
        if observations is None:
            observations = [self.snapshot] * 4
        if inventory is None:
            inventory = [[self.human], [{**self.human, 'state': 'Shutdown'}]]
        with patch.object(MODULE.time, 'time', return_value=1001), \
                patch.object(MODULE, 'observe', side_effect=observations), \
                patch.object(MODULE, 'devices', side_effect=inventory), \
                patch.object(MODULE, 'shutdown') as shutdown, patch.object(MODULE, 'quit_ui', return_value='requested') as quit_ui:
            report = MODULE.cleanup(self.root, self.previous if previous is None else previous,
                                    idle_seconds=600, apply=apply)
        return report, shutdown, quit_ui

    def test_idle_human_shutdown_and_normal_ui_quit_leave_no_reservations(self):
        report, shutdown, quit_ui = self.run_cleanup()
        shutdown.assert_called_once_with(self.root, 'human-device')
        quit_ui.assert_called_once_with(12, self.ui[12][1])
        self.assertEqual(len(report['actions']), 2)
        self.assertEqual(list((self.root / '.DerivedData/.active-sim').iterdir()), [])

    def test_active_play_and_tests_reset_timeout(self):
        for reason in ('device UI or Xcode in foreground', 'build, test, or device command active',
                       'simulator or inspection reservation preserved'):
            with self.subTest(reason=reason):
                report, shutdown, quit_ui = self.run_cleanup([{**self.snapshot, 'reason': reason}])
                shutdown.assert_not_called()
                quit_ui.assert_not_called()
                self.assertEqual(report['last_active'], 1001)

    def test_input_between_observations_and_new_sessions_restart_timeout(self):
        for current in ({**self.snapshot, 'input_idle': 5}, {**self.snapshot, 'session': [[99, 'new boot']]}):
            report, shutdown, _ = self.run_cleanup([current])
            shutdown.assert_not_called()
            self.assertGreaterEqual(report['last_active'], 996)

    def test_recent_input_does_not_double_the_timeout(self):
        report, _, _ = self.run_cleanup([{**self.snapshot, 'input_idle': 500}])
        self.assertEqual(report['last_active'], 501)

    def test_first_observation_and_clock_reversal_require_full_interval(self):
        for previous in ({}, {**self.previous, 'last_active': 2000}):
            report, shutdown, _ = self.run_cleanup(previous=previous)
            shutdown.assert_not_called()
            self.assertEqual(report['last_active'], 1001)

    def test_foreground_lease_or_new_boot_during_cleanup_cancels_shutdown(self):
        for change in ({'reason': 'new lease'}, {'input_idle': 0}, {'session': [[14, 'new session']]}):
            for index in (1, 2):
                observations = [self.snapshot] * index + [{**self.snapshot, **change}]
                _, shutdown, quit_ui = self.run_cleanup(observations)
                shutdown.assert_not_called()
                quit_ui.assert_not_called()

    def test_agent_foreign_or_transitioning_devices_keep_shared_ui(self):
        for name, state in [('Trinket Agent 1', 'Booted'), ('Another project', 'Booted'), ('Another project', 'Booting')]:
            other = {'name': name, 'state': state, 'udid': 'foreign-device'}
            _, shutdown, quit_ui = self.run_cleanup(inventory=[[self.human, other], [other]])
            shutdown.assert_called_once_with(self.root, 'human-device')
            quit_ui.assert_not_called()

    def test_new_activity_after_shutdown_preserves_ui(self):
        _, shutdown, quit_ui = self.run_cleanup([self.snapshot] * 3 + [{**self.snapshot, 'reason': 'foreground resumed'}])
        shutdown.assert_called_once()
        quit_ui.assert_not_called()

    def test_custom_device_set_guests_keep_shared_ui(self):
        _, shutdown, quit_ui = self.run_cleanup([self.snapshot] * 3 + [{**self.snapshot, 'guests': {99: ('start', 'launchd_sim /custom/set')}}])
        shutdown.assert_called_once()
        quit_ui.assert_not_called()

    def test_relaunched_ui_is_not_quit(self):
        self.run_cleanup([self.snapshot] * 3 + [{**self.snapshot, 'ui': {12: ('new start', self.ui[12][1])}}])[2].assert_not_called()

    def test_human_run_slot_and_agent_allocation_lock_are_preserved(self):
        directory = self.root / '.DerivedData/.active-sim'
        directory.mkdir(parents=True)
        for name in ('run.slot', '.sim-lifecycle.lock'):
            path = directory / name
            if name.endswith('lock'):
                path.mkdir()
            else:
                path.write_text('live human owner')
            _, shutdown, quit_ui = self.run_cleanup([self.snapshot])
            shutdown.assert_not_called()
            quit_ui.assert_not_called()
            self.assertTrue(path.exists())
            path.rmdir() if path.is_dir() else path.unlink()

    def test_failed_inventory_releases_only_our_reservations(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.run_cleanup(inventory=subprocess.TimeoutExpired('simctl', 45))
        self.assertEqual(list((self.root / '.DerivedData/.active-sim').iterdir()), [])

    def test_dry_run_does_not_reserve_or_mutate_devices(self):
        report, shutdown, quit_ui = self.run_cleanup([self.snapshot], apply=False)
        self.assertEqual(report['state'], 'eligible')
        shutdown.assert_not_called()
        quit_ui.assert_not_called()
        self.assertFalse((self.root / '.DerivedData').exists())

    def test_observation_respects_unknown_leases_and_foreign_test_guests(self):
        directory = self.root / '.DerivedData/.active-sim'
        directory.mkdir(parents=True)
        lease = directory / '2.slot'
        lease.write_text('unknown owner')
        with patch.object(MODULE, 'process_snapshot', return_value=self.ui), \
                patch.object(MODULE, 'legacy_runtime_owner', return_value=None), \
                patch.object(MODULE, 'foreground', return_value='other.app'), patch.object(MODULE, 'input_idle', return_value=1000):
            self.assertIn('reservation', MODULE.observe(self.root)['reason'])
            lease.unlink()
            for command in ('/runtime/Agents/xctest', '/runtime/TrinketUITests-Runner', '/Xcode/usr/bin/xcodebuild test'):
                with patch.object(MODULE, 'process_snapshot', return_value={**self.ui, 40: ('start', command)}):
                    self.assertIn('test', MODULE.observe(self.root)['reason'])

    def test_input_and_device_inventory_fail_closed(self):
        with patch.object(MODULE, 'command', return_value='{}'):
            with self.assertRaises(ValueError):
                MODULE.input_idle()
            with self.assertRaises(ValueError):
                MODULE.devices()

    def test_simulator_ui_arguments_and_paths_with_spaces_are_recognized(self):
        processes = {12: ('start', '/Applications/Xcode RC.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator -CurrentDeviceUDID abc')}
        self.assertEqual(MODULE.ui_processes(processes), processes)
        with patch.object(MODULE, 'command', return_value='requested') as command:
            MODULE.quit_ui(12, processes[12][1])
        self.assertEqual(command.call_args.args[-1], '/Applications/Xcode RC.app/Contents/Developer/Applications/Simulator.app')

    def test_installer_uses_primary_checkout_and_uninstall_keeps_devices(self):
        with patch.object(Path, 'home', return_value=self.root), patch.object(MODULE.subprocess, 'run') as run:
            MODULE.install(self.root, 600)
            path = self.root / 'Library/LaunchAgents' / (MODULE.LABEL + '.plist')
            value = plistlib.loads(path.read_bytes())
            self.assertEqual(value['StartInterval'], 60)
            self.assertEqual(value['ProgramArguments'][1], str(self.root / 'Scripts/simulator-idle-cleanup.py'))
            MODULE.install(self.root, 600, uninstall=True)
            self.assertFalse(path.exists())
            self.assertTrue(all(call.args[0][0] == '/bin/launchctl' for call in run.call_args_list))


if __name__ == '__main__':
    unittest.main()
