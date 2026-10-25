"""Only declared package tenants belong in a shard's compiler cache."""

from pathlib import Path
import tempfile
import unittest
from unittest import mock

from script_test_support import load_script

cache = load_script('cache_footprint_test', 'report-cache-footprint.py')


class CacheFootprintTests(unittest.TestCase):
    def fixture(self, root):
        for name in ('BattleEngine', 'TrinketCore'):
            manifest = root / 'Packages' / name / 'Package.swift'
            manifest.parent.mkdir(parents=True)
            manifest.touch()

    def test_scope_rejects_unknown_duplicate_and_traversal_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            self.fixture(root)
            for packages in ([], ['BattleEngine', 'BattleEngine'], ['../BattleEngine'], ['Missing']):
                with self.subTest(packages=packages), self.assertRaises(ValueError):
                    cache.cache_paths(root, packages, False)
            self.assertEqual(cache.cache_paths(root, ['BattleEngine'], True),
                             ['.DerivedData/host/BattleEngine', '.DerivedData/build-source-times.json'])
            self.assertEqual(cache.cache_paths(root, ['BattleEngine'], False),
                             ['.DerivedData/host/BattleEngine', '.DerivedData/packages/BattleEngine',
                              '.DerivedData/build-source-times.json'])

    def test_report_counts_dependencies_in_their_owner_and_excludes_other_tenants_without_reads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            self.fixture(root)
            for tenant in ('host/BattleEngine', 'host/TrinketCore', 'packages/BattleEngine'):
                dependency = root / '.DerivedData' / tenant / 'dependencies' / 'library.o'
                dependency.parent.mkdir(parents=True)
                dependency.write_bytes(b'x' * 8192)
            with mock.patch.object(Path, 'open', side_effect=AssertionError('contents read')):
                native = cache.footprint(root, ['BattleEngine'], True, 'fixture', 'key')
                simulator = cache.footprint(root, ['BattleEngine'], False, 'fixture', 'key')
            self.assertGreater(native['includedTenantAllocatedBytes'], 0)
            self.assertGreater(simulator['includedTenantAllocatedBytes'], native['includedTenantAllocatedBytes'])
            self.assertGreater(native['excludedTenantAllocatedBytes'], simulator['excludedTenantAllocatedBytes'])
            self.assertEqual(native['cacheKey'], 'key')
            self.assertTrue((root / '.DerivedData/host/TrinketCore/dependencies/library.o').exists())

    def test_report_does_not_follow_symlink_tenants_or_derived_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            self.fixture(root)
            foreign = root / 'foreign'
            foreign.mkdir()
            host = root / '.DerivedData/host'
            host.mkdir(parents=True)
            (host / 'BattleEngine').symlink_to(foreign, target_is_directory=True)
            self.assertEqual(cache.footprint(root, ['BattleEngine'], True, 'fixture', 'key')['tenants'], [])
            (host / 'BattleEngine').unlink()
            host.rmdir()
            host.parent.rmdir()
            (root / '.DerivedData').symlink_to(foreign, target_is_directory=True)
            self.assertEqual(cache.footprint(root, ['BattleEngine'], True, 'fixture', 'key')['tenants'], [])


if __name__ == '__main__':
    unittest.main()
