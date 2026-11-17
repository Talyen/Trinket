"""Protect physical-target selection, captured UI identity and chronological edits."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


capture = load("capture-launch-trailer")
edit = load("edit-launch-trailer")


class LaunchTrailerTests(unittest.TestCase):
    def test_target_must_be_a_wireless_physical_iphone(self):
        record = {"identifier": "core", "properties": {"hardware": {"reality": "physical", "udid": "phone"},
                  "connection": {"pairingState": "paired", "transportType": "wired"}}}
        with patch.object(capture, "device_json", side_effect=[{"devices": [record]}, {}]):
            with self.assertRaisesRegex(ValueError, "Wi-Fi"):
                capture.installed_phone("phone")

    def test_cues_are_relative_to_the_same_device_clock(self):
        result = capture.keep_times([{"id": "hero", "start": 1002.5, "end": 1004}],
                                    {"start": 1000, "duration": 30})
        self.assertEqual(result["shots"], [{"id": "hero", "start": 2.5, "end": 4}])
        with self.assertRaisesRegex(ValueError, "outside"):
            capture.keep_times([{"id": "boss", "start": 1002, "end": 1031}], {"start": 1000, "duration": 30})

    def test_doubled_30fps_frames_cannot_qualify_for_a_60fps_master(self):
        from LaunchTrailer.cadence import summarize
        changing = [(i / 60, 1.0) for i in range(61)]
        doubled = [(i / 60, i % 2) for i in range(61)]
        self.assertTrue(summarize(changing)["passed"])
        self.assertFalse(summarize(doubled)["passed"])

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "requires FFmpeg")
    def test_static_vfr_holds_fill_the_edit_even_with_no_source_frame_inside_the_cut(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "held.mp4"
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc2=s=96x160:r=30:d=6",
                            "-vf", "select='eq(n,0)+eq(n,60)+eq(n,135)+eq(n,179)'", "-fps_mode", "vfr",
                            "-c:v", "libx264", str(source)], check=True)
            timeline = root / "keep.json"
            timeline.write_text(json.dumps({"shots": [{"id": "hero", "start": 0.5, "end": 1.5},
                                                      {"id": "item", "start": 2.5, "end": 3.5}]}))
            output = root / "cut.mp4"
            with patch.object(sys, "argv", ["edit", "--source", str(source), "--timeline", str(timeline),
                                          "--fps", "30", "--output", str(output)]):
                edit.main()
            self.assertEqual(edit.probe(output)["streams"][0]["nb_frames"], "60")

    def test_overlapping_ordinary_shots_fail_before_encoding(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            timeline = root / "timeline.json"
            timeline.write_text(json.dumps({"shots": [
                {"id": "one", "start": 1, "end": 3}, {"id": "two", "start": 2, "end": 4}]}))
            stream = {"streams": [{"codec_type": "video"}], "format": {"duration": "10"}}
            args = ["edit", "--source", str(root / "raw.mov"), "--timeline", str(timeline),
                    "--output", str(root / "export.mp4")]
            with patch.object(sys, "argv", args), patch.object(edit, "probe", return_value=stream), \
                    patch.object(edit.subprocess, "run") as encode, self.assertRaises(SystemExit):
                edit.main()
            encode.assert_not_called()
