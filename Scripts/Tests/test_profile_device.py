from __future__ import annotations

import copy
import math
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

from script_test_support import load_script

module = load_script("profile_device", "profile-device.py")


class DeviceProfilingTests(unittest.TestCase):
    def test_ambiguous_phones_and_simulator_selection_never_deploy_to_arbitrary_device(self):
        phone = {"identifier": "phone", "properties": {
            "hardware": {"reality": "physical", "udid": "UDID"},
            "connection": {"pairingState": "paired"}, "state": {"name": "iPhone"}}}
        other = copy.deepcopy(phone)
        other["identifier"] = "other"
        sim = copy.deepcopy(phone)
        sim["properties"]["hardware"]["reality"] = "simulated"
        self.assertEqual(module.select_device([phone, sim], None), phone)
        for devices, requested in (([phone, other], None), ([sim], None), ([sim], "phone")):
            with self.subTest(requested=requested), self.assertRaises(ValueError):
                module.select_device(devices, requested)
        self.assertEqual(module.select_device([phone, other], "other"), other)

    def test_saved_partial_wrong_target_crash_and_empty_measurements_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            toc, samples = Path(directory) / "toc.xml", Path(directory) / "samples.xml"
            source = ET.fromstring('''<trace-toc><run><info><target>
                <device platform="iOS" uuid="PHONE"/>
                <process name="Trinket" type="launched" return-exit-status="0"/>
                </target><summary><duration>8.8</duration><end-reason>Time limit reached</end-reason>
                </summary></info><data><table schema="time-profile"/>
                <table schema="hitches-frame-lifetimes"/></data></run></trace-toc>''')
            sample_source = '''<trace-query-result><node xpath="//trace-toc[1]/run[1]/data[1]/table[1]"><row/></node>
                <node xpath="//trace-toc[1]/run[1]/data[1]/table[2]"><row/></node></trace-query-result>'''
            samples.write_text(sample_source)
            def save(tree):
                toc.write_text(ET.tostring(tree, encoding="unicode"))
            save(source)
            self.assertEqual(module.validate_trace(toc, samples, "PHONE", 8)["rowCounts"],
                             {"time-profile": 1, "hitches-frame-lifetimes": 1})
            for path, attribute, value in (
                ("run/info/summary/end-reason", None, "Device disconnected"),
                ("run/info/summary/duration", None, "1.4"),
                ("run/info/summary/duration", None, "nan"),
                ("run/info/target/device", "uuid", "HOST"),
                ("run/info/target/process", "return-exit-status", "1"),
            ):
                broken = copy.deepcopy(source)
                element = broken.find(path)
                if attribute:
                    element.set(attribute, value)
                else:
                    element.text = value
                save(broken)
                with self.subTest(value=value), self.assertRaises(ValueError):
                    module.validate_trace(toc, samples, "PHONE", 8)
            save(source)
            for empty_table in (1, 2):
                broken = ET.fromstring(sample_source)
                broken.findall("node")[empty_table - 1].clear()
                samples.write_text(ET.tostring(broken, encoding="unicode"))
                with self.subTest(empty_table=empty_table), self.assertRaises(ValueError):
                    module.validate_trace(toc, samples, "PHONE", 8)

    def test_watchdog_does_not_discard_valid_trace_during_slow_symbolication(self):
        clock = module.RecordingWatchdog(0, 8, 120)
        self.assertEqual(clock.observe("Starting recording", 100), 120)
        self.assertEqual(clock.observe("Ctrl-C to stop", 110), 148)
        self.assertEqual(clock.observe("Reached specified time ", 119), 148)
        self.assertTrue(math.isinf(clock.observe("limit, ending recording", 120)))
        self.assertTrue(math.isinf(clock.observe("Symbols " * 10000, 900)))

    def test_exit_zero_disconnect_is_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "recording error"):
                module.run([sys.executable, "-c", "print('Device got disconnected, ending recording...')"],
                           Path(directory) / "capture.log", duration=5)

    def test_stalled_command_cleanup_preserves_unrelated_process(self):
        unrelated = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], start_new_session=True)
        try:
            with tempfile.TemporaryDirectory() as directory, self.assertRaisesRegex(RuntimeError, "stalled"):
                module.run([sys.executable, "-c", "import time; time.sleep(60)"],
                           Path(directory) / "stalled.log", timeout=0)
            self.assertIsNone(unrelated.poll())
        finally:
            unrelated.terminate()
            unrelated.wait(timeout=5)

    def test_cleanup_permission_error_is_ignored_only_after_owned_process_exits(self):
        for status in (0, None):
            process = mock.Mock(pid=123)
            process.poll.side_effect = [None, status]
            with self.subTest(exit_status=status), mock.patch.object(
                    module.os, "killpg", side_effect=PermissionError("process group unavailable")):
                if status is None:
                    with self.assertRaises(PermissionError):
                        module.stop_owned(process)
                else:
                    module.stop_owned(process)

    def test_distribution_signature_is_refused_before_installation(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": module.BUNDLE}))
            entitlements = plistlib.dumps({"get-task-allow": False})
            profile = plistlib.dumps({"Entitlements": {"get-task-allow": False}})
            with mock.patch.object(module.subprocess, "run"), \
                    mock.patch.object(module.subprocess, "check_output", side_effect=[entitlements, profile]), \
                    self.assertRaisesRegex(ValueError, "Distribution/TestFlight"):
                module.check_app(app, "PHONE")
