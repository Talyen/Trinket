from pathlib import Path
import tempfile
import unittest
from unittest import mock

from internal import profile_exports as exports


class ProfileExportRetentionTests(unittest.TestCase):
    def test_default_removes_only_owned_intermediates_on_success_and_failure(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as name:
                root = Path(name); output = root / "capture"; output.mkdir()
                trace = output / "recording.trace"; trace.mkdir()
                summary = output / "result.json"; summary.write_text("{}")
                workspace = None
                try:
                    with exports.measurement_exports(output, False, 32, scratch=root) as workspace:
                        (workspace / "samples.xml").write_text("derived")
                        if fail:
                            raise RuntimeError("analysis failed")
                except RuntimeError:
                    pass
                self.assertFalse(workspace.exists())
                self.assertTrue(trace.is_dir())
                self.assertEqual(summary.read_text(), "{}")

    def test_explicit_pin_preserves_investigation_exports(self):
        with tempfile.TemporaryDirectory() as name:
            output = Path(name)
            with exports.measurement_exports(output, True, 32) as workspace:
                sample = workspace / "samples.xml"; sample.write_text("evidence")
            self.assertEqual(sample.read_text(), "evidence")
            self.assertTrue((workspace / ".retention-keep").is_file())

    def test_budget_refuses_new_output_and_preserves_crash_remnant(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); old = root / (exports.PREFIX + "old"); old.mkdir()
            data = old / "samples.xml"; data.write_text("123456789")
            with mock.patch.object(exports, "SCRATCH_BUDGET", 10):
                with self.assertRaisesRegex(ValueError, "budget exceeded"):
                    with exports.measurement_exports(root, False, 1, scratch=root):
                        self.fail("must not create a new export")
            self.assertEqual(data.read_text(), "123456789")

    def test_child_file_limit_does_not_change_test_process_limits(self):
        with mock.patch.object(exports.resource, "setrlimit") as set_limit:
            exports.limit_export_file(123)
            set_limit.assert_called_once_with(exports.resource.RLIMIT_FSIZE, (123, 123))

    def test_symlinked_scratch_is_not_followed_or_removed(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); outside = root / "original"; outside.mkdir()
            link = root / (exports.PREFIX + "unknown"); link.symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "Symlink"):
                exports.scratch_bytes(root)
            self.assertTrue(outside.is_dir())

    def test_active_temporary_group_blocks_another_group_without_process_inventory(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            with exports.measurement_exports(root, False, 32, scratch=root):
                with self.assertRaisesRegex(ValueError, "active"):
                    with exports.measurement_exports(root, False, 32, scratch=root):
                        self.fail("concurrent group must not begin")

    def test_pinned_analysis_failure_keeps_the_derived_evidence(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            with self.assertRaisesRegex(RuntimeError, "analysis failed"):
                with exports.measurement_exports(root, True, 32) as workspace:
                    sample = workspace / "samples.xml"; sample.write_text("evidence")
                    raise RuntimeError("analysis failed")
            self.assertEqual(sample.read_text(), "evidence")

    def test_logs_preserve_small_output_and_bound_large_output_with_final_error(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "command.log"
            with exports.BoundedLog(path, 1024) as log:
                log.write(b"normal progress\n")
            self.assertEqual(path.read_bytes(), b"normal progress\n")
            with exports.BoundedLog(path, 1024) as log:
                log.write(b"start\n" + b"x" * 10000)
                log.write(b"final failure details\n")
            data = path.read_bytes()
            self.assertLessEqual(len(data), 1024)
            self.assertTrue(data.startswith(b"start\n"))
            self.assertTrue(data.endswith(b"final failure details\n"))
            self.assertIn(exports.BoundedLog.marker, data)
