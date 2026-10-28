"""Storage reports preserve unknown worktree state and never mutate outputs."""
from pathlib import Path
import subprocess
from unittest import mock

from script_test_support import ScriptRegressionTestCase, load_script

report = load_script('storage_report_test', 'report-storage.py')


class StorageReportTests(ScriptRegressionTestCase):
    def test_unavailable_status_is_not_called_clean(self):
        listing = subprocess.CompletedProcess([], 0, 'worktree /main\0HEAD a\0\0worktree /task\0HEAD b\0', '')
        ancestor = subprocess.CompletedProcess([], 0, '', '')
        with mock.patch.object(report, 'command', side_effect=[(listing, ''), (ancestor, ''), (None, 'timeout')]), \
             mock.patch('builtins.print') as output:
            report.worktree_inventory(Path('/main'))
        self.assertIn('status unknown', str(output.call_args_list))
        self.assertIn('activity and ignored files not assessed', str(output.call_args_list))

    def test_sizes_do_not_follow_symlinks(self):
        with mock.patch.object(Path, 'exists', return_value=True), \
             mock.patch.object(Path, 'is_symlink', return_value=True), \
             mock.patch.object(report, 'command') as command:
            self.assertIsNone(report.allocated(Path('/fake')))
            command.assert_not_called()
