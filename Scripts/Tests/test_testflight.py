"""Exercise deployment orchestration without credentials, Xcode, or Ruby gems."""

import shutil
import subprocess
import unittest

from script_test_support import ROOT


class TestFlightTests(unittest.TestCase):
    def test_deployment_contracts(self):
        ruby = shutil.which("ruby")
        self.assertIsNotNone(ruby, "Ruby is required for the credential-free TestFlight script regressions")
        result = subprocess.run(
            [ruby, str(ROOT / "Scripts/Tests/testflight_test.rb")],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("TestFlight regression scenarios passed", result.stdout)

    @unittest.skipUnless((ROOT / ".tools/testflight/gems/bin/bundle").exists(),
                         "Optional pinned-Fastlane adapter check requires setup-testflight.sh")
    def test_installed_fastlane_adapter(self):
        result = subprocess.run(
            ["bash", "-c", 'source Scripts/lib/testflight-tools.sh\n'
             'trinket_testflight_tools "$PWD" false\n'
             '"$TRINKET_BUNDLE" _4.0.15_ exec ruby Scripts/Tests/testflight_test.rb --fastlane'],
            cwd=ROOT, capture_output=True, text=True, timeout=45,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Pinned Fastlane adapter scenarios passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
