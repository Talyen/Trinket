"""Scoped leases must protect custom paths and fail closed on ambiguous owners."""
import os
from pathlib import Path
import subprocess
import select
import time
import tempfile
import unittest
from unittest import mock

from internal import output_retention as retention
from internal import resource_lease
from script_test_support import ROOT


class ResourceLeaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.primary = Path(self.temp.name).resolve()
        self.task = self.primary / '.worktrees/task'
        self.task.mkdir(parents=True)
        (self.task / '.DerivedData').mkdir()
        self.roots = mock.patch.object(resource_lease, 'worktree_roots', return_value=(self.primary, self.task))
        self.roots.start()
        self.addCleanup(self.roots.stop)
        self.process = subprocess.Popen(['sleep', '90'])
        self.addCleanup(self.stop_process)
        self.pid = self.process.pid
        self.processes = retention.process_snapshot()
        started = ' '.join(subprocess.check_output(['ps', '-p', str(self.pid), '-o', 'lstart='], text=True).split())
        self.processes[self.pid] = (started, 'sleep')
        self.slot = self.primary / '.DerivedData/.active-build/fixture.slot'
        self.slot.parent.mkdir(parents=True)
        self.candidate = self.primary / '.DerivedData/Build/Intermediates.noindex'
        self.candidate.mkdir(parents=True)

    def stop_process(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)

    def marker(self, paths=()):
        token = resource_lease.make_scope(self.pid, self.task, list(map(str, paths)))
        self.slot.write_text(f'{self.pid} build {token}\n')

    def protect(self, path=None):
        with mock.patch.object(retention, 'legacy_runtime_owner', return_value=None), \
             mock.patch.object(retention, 'primary_worktree_root', return_value=self.primary):
            return retention.protection(path or self.candidate, self.primary, self.processes, scoped=True)

    def test_different_checkout_does_not_protect_unrelated_cache(self):
        self.marker()
        self.assertEqual(self.protect(), '')
        with mock.patch.object(retention, 'legacy_runtime_owner', return_value=None), \
             mock.patch.object(retention, 'primary_worktree_root', return_value=self.primary):
            self.assertIn('active lease', retention.protection(self.candidate, self.primary, self.processes))

    def test_custom_output_and_ancestor_overlap_remain_protected(self):
        custom = self.candidate / 'nested'
        custom.mkdir()
        self.marker([custom])
        self.assertIn('active lease', self.protect())

    def test_custom_report_root_remains_protected(self):
        report = self.primary / 'BalanceSweepReports/investigation'
        report.mkdir(parents=True)
        self.marker([report])
        self.assertIn('active lease', self.protect(report))

    def test_legacy_malformed_and_reused_pid_remain_global(self):
        for marker in (f'{self.pid} build', f'{self.pid} build scope-v1:bad'):
            self.slot.write_text(marker)
            self.assertIn('active lease', self.protect())
        self.marker()
        self.processes[self.pid] = ('different process start', 'sleep')
        self.assertIn('active lease', self.protect())

    def test_retargeted_symlink_invalidates_scope(self):
        link = self.primary / 'custom'
        link.symlink_to(self.task, target_is_directory=True)
        self.marker([link])
        self.assertIn('active lease', self.protect())
        link.unlink()
        link.symlink_to(self.candidate, target_is_directory=True)
        self.assertIn('active lease', self.protect())

    def test_missing_declared_output_remains_globally_protected(self):
        self.marker([self.primary / 'not-created-yet'])
        self.assertIn('active lease', self.protect())

    def test_failed_owner_inspection_remains_globally_protected(self):
        self.marker()
        self.processes.pop(self.pid)
        with mock.patch.object(resource_lease.subprocess, 'check_output', side_effect=subprocess.TimeoutExpired('ps', 5)):
            self.assertIn('active lease', self.protect())

    def test_lifecycle_lock_blocks_new_mutation(self):
        with retention.lifecycle_guard(self.primary, apply=True) as acquired:
            self.assertTrue(acquired)
            with retention.lifecycle_guard(self.primary, apply=True) as second:
                self.assertFalse(second)
        with retention.lifecycle_guard(self.primary, apply=True) as acquired:
            self.assertTrue(acquired)

    def test_cache_cleanup_rechecks_scoped_owner_under_lifecycle_lock(self):
        target = self.candidate / 'object'
        target.write_text('rebuildable')
        old = time.time() - 2 * 86400
        for path in (target, self.candidate):
            os.utime(path, (old, old))
        self.marker()
        with mock.patch.object(retention, 'legacy_runtime_owner', return_value=None), \
             mock.patch.object(retention, 'primary_worktree_root', return_value=self.primary), \
             mock.patch.object(retention, 'process_snapshot', return_value=self.processes), \
             mock.patch.object(retention, 'unmanaged_build_active', return_value=False), \
             mock.patch.object(retention.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 1, '', '')):
            removed, _ = retention.expire_run_caches(self.primary, apply=True, now=time.time(),
                                                     processes=self.processes, verbose=False, max_age=86400,
                                                     intermediates_only=True)
        self.assertEqual(removed, 1)
        self.assertFalse(target.exists())

    def test_custom_scope_prevents_cleanup_under_lifecycle_lock(self):
        target = self.candidate / 'object'
        target.write_text('protected')
        old = time.time() - 2 * 86400
        for path in (target, self.candidate):
            os.utime(path, (old, old))
        self.marker([self.candidate])
        with mock.patch.object(retention, 'legacy_runtime_owner', return_value=None), \
             mock.patch.object(retention, 'primary_worktree_root', return_value=self.primary), \
             mock.patch.object(retention, 'process_snapshot', return_value=self.processes), \
             mock.patch.object(retention, 'unmanaged_build_active', return_value=False), \
             mock.patch.object(retention.subprocess, 'run', return_value=subprocess.CompletedProcess('lsof', 1, '', '')):
            removed, _ = retention.expire_run_caches(self.primary, apply=True, now=time.time(),
                                                     processes=self.processes, verbose=False, max_age=86400,
                                                     intermediates_only=True)
        self.assertEqual(removed, 0)
        self.assertTrue(target.exists())

    def test_ui_lease_waits_for_cleanup_lifecycle_lock(self):
        script = ('source "$1/Scripts/lib/lock.sh"\nsource "$1/Scripts/lib/slots.sh"\n'
                  'TRINKET_SIM_STATE_ROOT="$2/.DerivedData"\n'
                  'TRINKET_UI_ACTIVE_DIR="$2/.DerivedData/.active-ui"\n'
                  'trinket_ui_slot_acquire\nprintf "ready\\n"\nread -r done\n')
        with retention.lifecycle_guard(self.primary, apply=True) as acquired:
            self.assertTrue(acquired)
            worker = subprocess.Popen(['bash', '-c', script, 'fixture', str(ROOT), str(self.primary)],
                                      stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            self.addCleanup(lambda: worker.kill() if worker.poll() is None else None)
            time.sleep(0.25)
            self.assertEqual(list((self.primary / '.DerivedData/.active-ui').glob('*.slot')), [])
        ready, _, _ = select.select([worker.stdout], [], [], 5)
        self.assertTrue(ready, 'UI producer did not acquire its lease after cleanup released the lock')
        self.assertEqual(worker.stdout.readline(), 'ready\n')
        output, error = worker.communicate('done\n', timeout=5)
        self.assertEqual(worker.returncode, 0, output + error)

    def test_shell_producer_publishes_checkout_and_custom_output(self):
        custom = self.primary / 'custom output'
        custom.mkdir()
        script = ('source "$1/Scripts/lib/lock.sh"\nsource "$1/Scripts/lib/slots.sh"\n'
                  'TRINKET_REPO_ROOT="$1"\nTRINKET_SIM_STATE_ROOT="$2/.DerivedData"\n'
                  'DERIVED_DATA_PATH="$2/custom output"\ntrinket_build_lease_acquire\n'
                  'printf "%s\\n" "$TRINKET_BUILD_LEASE_PATH"\nread -r done\n')
        worker = subprocess.Popen(['bash', '-c', script, 'fixture', str(ROOT), str(self.primary)],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: worker.kill() if worker.poll() is None else None)
        ready, _, _ = select.select([worker.stdout], [], [], 10)
        self.assertTrue(ready, 'producer did not publish a lease')
        slot = Path(worker.stdout.readline().strip())
        started = ' '.join(subprocess.check_output(['ps', '-p', str(worker.pid), '-o', 'lstart='], text=True).split())
        with mock.patch.object(resource_lease, 'worktree_roots', return_value=(ROOT.resolve(),)):
            scopes = resource_lease.scope_for(slot, worker.pid, {worker.pid: (started, 'fixture')}, ROOT)
        self.assertIsNotNone(scopes)
        self.assertIn(ROOT.resolve(), scopes)
        self.assertIn(custom, scopes)
        output, error = worker.communicate('done\n', timeout=5)
        self.assertEqual(worker.returncode, 0, output + error)
