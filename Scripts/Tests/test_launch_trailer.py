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

    @unittest.skipUnless(shutil.which("ffmpeg"), "requires FFmpeg")
    def test_focus_leaves_subject_lit_then_releases_before_the_next_cut(self):
        from LaunchTrailer.treatment import compose
        filters = ["[0:v]null[viewport]"]
        label = compose(filters, [{"id": "item", "output_start": 0.5, "output_end": 1.5,
                                  "effects": [{"type": "focus", "from": 0, "to": 1, "center": [0.5, 0.5],
                                               "radius": [0.35, 0.3], "strength": 0.5}]}], 30, 64, 96)
        pixels = subprocess.check_output(["ffmpeg", "-v", "error", "-f", "lavfi", "-i",
                                          "color=white:s=64x96:r=30:d=2", "-filter_complex", ";".join(filters),
                                          "-map", f"[{label}]", "-pix_fmt", "gray", "-f", "rawvideo", "-"])
        frame = 64 * 96
        self.assertEqual(len(pixels), 60 * frame)
        self.assertGreater(pixels[30 * frame + frame // 2 + 32], 245)
        self.assertLess(pixels[30 * frame + 2], 160)
        self.assertGreater(pixels[5 * frame + 2], 245)
        self.assertGreater(pixels[52 * frame + 2], 245)

    def test_capture_recipe_keeps_action_handles_and_chronological_frame_boundaries(self):
        handles = {"shots": [{"id": "hero", "start": 4.01, "end": 6.45},
                             {"id": "fire-arrow", "start": 8.2, "end": 10.6}]}
        shots = capture.cut_gestures(handles, 20)["shots"]
        self.assertAlmostEqual(shots[0]["start"] * 60, round(shots[0]["start"] * 60))
        self.assertLess(shots[0]["end"], shots[1]["start"])
        self.assertEqual(shots[1]["effects"][0]["type"], "push")
        with self.assertRaisesRegex(ValueError, "exceeds"):
            capture.cut_gestures(handles, 8.5)

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
