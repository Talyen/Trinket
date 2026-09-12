"""Executable product transfer and incremental cache retention contracts."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildArtifactTests(unittest.TestCase):
    def test_product_archive_preserves_executables_and_excludes_build_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            products = root / "Build/Products"
            executable = products / "Debug-iphonesimulator/Trinket.app/Trinket"
            executable.parent.mkdir(parents=True)
            executable.write_text("#!/bin/sh\nexit 0\n")
            executable.chmod(0o755)
            (products / "current-app").symlink_to("Debug-iphonesimulator/Trinket.app")
            (products / "Trinket.xctestrun").write_text("test configuration")
            for path in ("TestResults/.last-build-test.stamp", "TestResults/.last-build-test.stamp.gitstatus",
                         "TestResults/raw/build.log", "ModuleCache.noindex/cache", "SourcePackages/cache",
                         "Build/Intermediates.noindex/build.db"):
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("fixture")
            command = [str(ROOT / "Scripts/stage-ci-test-artifact.sh"), str(root)]
            subprocess.run(command, check=True, capture_output=True)
            # A repeat upload must contain the current products, without accumulating archives.
            (products / "removed").touch()
            subprocess.run(command, check=True, capture_output=True)
            (products / "removed").unlink()
            subprocess.run(command, check=True, capture_output=True)
            restored = root / "restored"
            restored.mkdir()
            subprocess.run(["tar", "-xf", str(root / "ci-test-artifact.tar"), "-C", str(restored)], check=True)
            self.assertTrue(os.access(restored / executable.relative_to(root), os.X_OK))
            self.assertTrue((restored / "Build/Products/current-app").is_symlink())
            self.assertTrue((restored / "Build/Products/Trinket.xctestrun").is_file())
            self.assertTrue((restored / "TestResults/.last-build-test.stamp").is_file())
            self.assertTrue((restored / "TestResults/.last-build-test.stamp.gitstatus").is_file())
            for path in ("TestResults/raw", "ModuleCache.noindex", "SourcePackages", "Build/Intermediates.noindex",
                         "Build/Products/removed", "ci-test-artifact.tar"):
                self.assertFalse((restored / path).exists(), path)

    def test_ci_pruning_retains_incremental_state_and_rejects_foreign_directories(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "Scripts/prune-derived-data-cache.sh", scripts)
            shutil.copy2(ROOT / "Scripts/lib/derived-data.sh", scripts / "derived-data.sh")
            (scripts / "run-env.sh").write_text(
                'source Scripts/derived-data.sh\ntrinket_derived_data_age_prune() { :; }\n'
                'trinket_ui_slot_reap() { :; }\ntrinket_sim_slot_reap() { :; }\n'
            )
            kept = ("Build/Products/app", "Build/Intermediates.noindex/build.db", "CompilationCache.noindex/cache",
                    "SDKStatCaches.noindex/cache", "ModuleCache.noindex/cache",
                    "packages/Core/Build/Intermediates.noindex/build.db")
            removed = ("Index.noindex/index", "Logs/build", "TestResults/test.xcresult/Info.plist")
            for path in kept + removed:
                target = root / ".DerivedData" / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("fixture")
            subprocess.run([str(scripts / "prune-derived-data-cache.sh"), "--ci"], check=True, capture_output=True)
            for path in kept:
                self.assertTrue((root / ".DerivedData" / path).exists(), path)
            for path in removed:
                self.assertFalse((root / ".DerivedData" / path).exists(), path)
            foreign = root / "foreign"
            foreign.mkdir()
            sentinel = foreign / "keep"
            sentinel.write_text("untouched")
            result = subprocess.run([str(scripts / "prune-derived-data-cache.sh"), "--ci", str(foreign)], capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(sentinel.read_text(), "untouched")

    def test_storekit_change_invalidates_test_reuse(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            for name in ("build-freshness.sh", "build-inputs.env"):
                shutil.copy2(ROOT / "Scripts" / name, root / "Scripts" / name)
            (root / "StoreKit").mkdir()
            source = root / "StoreKit/Trinket.storekit"
            source.write_text("before")
            environment = {k: v for k, v in os.environ.items() if k not in ("CI", "GITHUB_ACTIONS")}
            prefix = 'source Scripts/build-freshness.sh; '
            subprocess.run(["bash", "-ec", prefix + 'touch_build_stamp results smoke'], cwd=root, env=environment, check=True)
            source.write_text("after")
            stamp = next((root / "results").glob("*.stamp"))
            os.utime(source, (stamp.stat().st_mtime + 2, stamp.stat().st_mtime + 2))
            result = subprocess.run(["bash", "-ec", prefix + 'assert_no_build_inputs_are_fresh "$(build_stamp_path results smoke)" smoke'],
                                    cwd=root, env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("StoreKit/Trinket.storekit", result.stderr)


if __name__ == "__main__":
    unittest.main()
