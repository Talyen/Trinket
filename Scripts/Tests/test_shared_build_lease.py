"""Shared build consumers block retention until their own lease ends."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import ROOT
from internal import output_retention as retention
from internal.shared_build_lease import shared_build_lease


class SharedBuildLeaseTests(unittest.TestCase):
    def test_unmanaged_process_and_inspection_errors_fail_closed(self):
        with patch.object(retention.subprocess, 'run', return_value=subprocess.CompletedProcess('pgrep', 0, '123\n', '')):
            self.assertTrue(retention.unmanaged_build_active())
        with patch.object(retention.subprocess, 'run', side_effect=subprocess.TimeoutExpired('pgrep', 5)):
            self.assertTrue(retention.unmanaged_build_active())

    def test_python_producer_registers_and_releases(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            with shared_build_lease(root):
                markers = list((root / '.DerivedData/.active-build').glob('*.slot'))
                self.assertEqual(len(markers), 1)
                self.assertEqual(markers[0].read_text().split()[0], str(os.getpid()))
            self.assertFalse(markers[0].exists())

    def test_symlinked_lease_state_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            derived = root / '.DerivedData'
            derived.mkdir()
            (derived / '.active-build').symlink_to(root, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                with shared_build_lease(root):
                    self.fail('unsafe lease must not start')

    def test_shell_producer_blocks_retention_until_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            script = ('source "$1/Scripts/lib/lock.sh"\nsource "$1/Scripts/lib/slots.sh"\n'
                      'TRINKET_SIM_STATE_ROOT="$2/.DerivedData"\ntrinket_build_lease_acquire\n'
                      'printf "%s\\n" "$TRINKET_BUILD_LEASE_PATH"\nread -r done\n')
            process = subprocess.Popen(['bash', '-c', script, 'fixture', str(ROOT), str(root)],
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                marker = Path(process.stdout.readline().strip())
                self.assertTrue(marker.is_file())
                target = root / '.DerivedData/Build/Intermediates.noindex'
                target.mkdir(parents=True)
                with patch.object(retention, 'process_snapshot', return_value={}), \
                     patch.object(retention, 'legacy_runtime_owner', return_value=None):
                    self.assertIn('active lease', retention.protection(target, root, {}))
            finally:
                stdout, stderr = process.communicate('done\n', timeout=10)
                self.assertEqual(process.returncode, 0, stdout + stderr)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()
