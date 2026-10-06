import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',"Scripts/agent-sim-lifetime.py", "Scripts/ensure-simulator.sh", "Scripts/lib/simctl.sh")
from script_test_support import ROOT, load_script

MODULE = load_script("agent_sim_lifetime", "agent-sim-lifetime.py")


class AgentSimulatorLifetimeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.slot = Path(self.directory.name) / "1.slot"
        self.record = {"slot": str(self.slot), "lease": "100 old-run\n", "owner": 100, "started": "old start",
                       "token": "old-token", "name": "Trinket Agent 1", "udid": "agent-device"}

    def commands(self, name="Trinket Agent 1", guests=""):
        listing = '{"devices":{"runtime":[{"udid":"agent-device","name":"' + name + '","state":"Booted"}]}}'
        return patch.object(MODULE.subprocess, "run", side_effect=[subprocess.CompletedProcess([], 0, listing), subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0, listing.replace('Booted', 'Shutdown'))]), patch.object(MODULE.subprocess, "check_output", return_value=guests)

    def test_released_agent_shutdown_targets_exact_device_and_removes_reservation(self):
        commands, guests = self.commands()
        with commands as run, guests:
            self.assertTrue(MODULE.cleanup(self.record))
            self.assertEqual(run.call_args_list[1].args[0], ["xcrun", "simctl", "shutdown", "agent-device"])
        self.assertFalse(self.slot.exists())
        self.assertFalse((self.slot.parent / ".sim-lifecycle.lock").exists())

    def test_new_lease_and_live_owner_are_preserved(self):
        for lease, started in [("200 newer-run\n", "old start"), (self.record["lease"], "old start")]:
            self.slot.write_text(lease)
            with patch.object(MODULE, "identity", return_value=started), patch.object(MODULE.subprocess, "run") as run:
                self.assertTrue(MODULE.cleanup(self.record))
                run.assert_not_called()
            self.assertEqual(self.slot.read_text(), lease)

    def test_crashed_owner_is_reaped_without_deleting_another_lease(self):
        self.slot.write_text(self.record["lease"])
        commands, guests = self.commands()
        with patch.object(MODULE, "identity", return_value="reused PID"), commands as run, guests:
            self.assertTrue(MODULE.cleanup(self.record))
            self.assertEqual(run.call_count, 3)

    def test_human_rename_and_foreign_xctest_prevent_shutdown(self):
        for name, processes in [("Trinket Run", ""), ("Trinket Agent 1", "10 1 launchd_sim /Devices/agent-device/data\n11 10 /runtime/Agents/xctest\n")]:
            commands, guests = self.commands(name, processes)
            with commands as run, guests:
                self.assertTrue(MODULE.cleanup(self.record))
                self.assertEqual(run.call_count, 1)

    def test_failed_process_snapshot_prevents_shutdown(self):
        commands, _ = self.commands()
        with commands as run, patch.object(MODULE.subprocess, "check_output", side_effect=subprocess.CalledProcessError(1, "ps")):
            with self.assertRaises(subprocess.CalledProcessError):
                MODULE.cleanup(self.record)
            self.assertEqual(run.call_count, 1)
        self.assertFalse(self.slot.exists())

    def test_failed_or_unparseable_owner_snapshot_is_not_treated_as_exit(self):
        for result in [subprocess.CompletedProcess([], 2, "", ""), subprocess.CompletedProcess([], 1, "", "inspection failed"), subprocess.CompletedProcess([], 0, "unparseable", "")]:
            with patch.object(MODULE.subprocess, "run", return_value=result), self.assertRaises(RuntimeError):
                MODULE.identity(100)

    def test_lease_deleted_during_notification_setup_is_a_release(self):
        with patch.object(Path, "read_text", side_effect=FileNotFoundError):
            self.assertFalse(MODULE.lease_active(self.record))

    def test_cleanup_reservation_cannot_replace_an_active_acquisition(self):
        lock = self.slot.parent / ".sim-lifecycle.lock"
        lock.mkdir()
        (lock / "pid").write_text("another owner")
        with patch.object(MODULE.subprocess, "run") as run:
            self.assertFalse(MODULE.cleanup(self.record))
            run.assert_not_called()
        self.assertEqual((lock / "pid").read_text(), "another owner")

    def test_busy_cleanup_lock_is_retried_until_idle_device_is_released(self):
        path = self.slot.with_suffix(".lifetime.json")
        self.record["grace"] = 0
        path.write_text(json.dumps(self.record))
        with patch.object(MODULE, "wait_release"), patch.object(MODULE.time, "sleep"), \
                patch.object(MODULE, "cleanup", side_effect=[False, True]) as cleanup:
            MODULE.watch(path, self.record["token"])
        self.assertEqual(cleanup.call_count, 2)
        self.assertFalse(path.exists())

    def test_replaced_watcher_cannot_shut_down_a_newly_released_device(self):
        path = self.slot.with_suffix(".lifetime.json")
        self.record["grace"] = 0
        path.write_text(json.dumps(self.record))
        def replace_record(_):
            path.write_text(json.dumps({**self.record, "token": "new-token"}))
        with patch.object(MODULE, "wait_release", side_effect=replace_record), \
                patch.object(MODULE.time, "sleep"), patch.object(MODULE, "cleanup") as cleanup:
            MODULE.watch(path, self.record["token"])
        cleanup.assert_not_called()
        self.assertEqual(json.loads(path.read_text())["token"], "new-token")

    def test_release_during_notification_setup_does_not_wait_for_owner_exit(self):
        self.slot.write_text(self.record["lease"])
        class Queue:
            def __init__(inner):
                self.slot.unlink()
            def close(inner):
                pass
            def control(inner, changes, count, timeout):
                if timeout is None:
                    raise AssertionError("Blocked after the release notification was missed")
                return []
        with patch.object(MODULE, "identity", return_value=self.record["started"]), \
                patch.object(MODULE.select, "kqueue", Queue, create=True), \
                patch.object(MODULE.select, "kevent", create=True):
            MODULE.wait_release(self.record)

    def simulator_environment(self):
        fake = self.slot.parent / "xcrun"
        state = self.slot.parent / "shutdown"
        fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
state = pathlib.Path(os.environ["TRINKET_LIFETIME_FIXTURE_STATE"])
if sys.argv[1:3] == ["simctl", "shutdown"]:
    state.write_text(sys.argv[3])
else:
    print(json.dumps({"devices":{"runtime":[{"udid":"agent-device","name":"Trinket Agent 1","state":"Shutdown" if state.exists() else "Booted"}]}}))
''')
        fake.chmod(0o755)
        return {**os.environ, "PATH": str(self.slot.parent) + os.pathsep + os.environ["PATH"],
                "TRINKET_LIFETIME_FIXTURE_STATE": str(state)}, state

    def test_nested_command_registers_parent_lease_and_leaves_it_active(self):
        environment, state = self.simulator_environment()
        self.slot.write_text(f"{os.getpid()} parent-run\n")
        environment.update({"TRINKET_ISOLATE": "1", "TRINKET_SIM_SLOT_PATH": str(self.slot),
                            "TRINKET_SIM_SLOT_OWNER_PID": f"{os.getpid()}:0", "SIMULATOR_UDID": "agent-device",
                            "SIMULATOR_NAME": "Trinket Agent 1", "TRINKET_AGENT_SIM_IDLE_SECONDS": "0"})
        subprocess.run(["bash", "-c", 'set -euo pipefail; '
                        'source "$1/Scripts/lib/simctl.sh"; '
                        'trinket_run_env_repo_root() { printf "%s" "$TRINKET_REPO_ROOT"; }; trinket_watch_agent_simulator',
                        "_", str(ROOT)],
                       env={**environment, "TRINKET_REPO_ROOT": str(ROOT)}, check=True, timeout=5)
        record_file = self.slot.with_suffix(".lifetime.json")
        self.assertTrue(record_file.exists(), "Nested launcher failed to register the parent lease")
        record = json.loads(record_file.read_text())
        try:
            self.assertEqual(record["owner"], os.getpid())
            self.assertFalse(state.exists(), "Child exit shut down the parent's active device")
            self.slot.unlink()
            deadline = time.monotonic() + 5
            while record_file.exists() and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertFalse(record_file.exists())
            self.assertFalse(record_file.with_suffix(".log").exists())
            self.assertEqual(state.read_text(), "agent-device")
        finally:
            if MODULE.identity(record["guardian"]) == record["guardianStarted"]:
                os.kill(record["guardian"], 15)



if __name__ == "__main__":
    unittest.main()
