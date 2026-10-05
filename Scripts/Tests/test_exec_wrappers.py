#!/usr/bin/env python3
"""Protect wrapper launch paths and positive native test execution evidence."""

SCRIPT_INPUTS = (
    'Scripts/test-package-host.sh',
    'Scripts/phase-timing.py',
)

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


class ExecWrapperTests(unittest.TestCase):
    def test_native_pilot_requires_positive_swift_testing_verdict(self):
        import os
        import shutil
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            for name in ('test-package-host.sh', 'phase-timing.py'):
                shutil.copy2(ROOT / 'Scripts' / name, scripts / name)
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { :; }\n')
            (scripts / 'run-env.sh').write_text('trinket_run_env_init() { export RESULTS_DIR="$PWD/results" DERIVED_DATA_PATH="$PWD/dd"; }\n')
            tools = root / 'tools'
            tools.mkdir()
            swift = tools / 'swift'
            swift.write_text('#!/bin/sh\nprintf "%s\\n" "$VERDICT"\n')
            swift.chmod(0o755)
            for verdict, expected in (
                ('✔ Test run with 810 tests in 108 suites passed after 0.769 seconds.', 0),
                ('✔ Test run with 0 tests in 0 suites passed after 0.0 seconds.', 1),
                ('Build complete!', 1),
                ('✘ Test run with 810 tests failed after 1.0 seconds.', 1),
            ):
                result = subprocess.run(['bash', str(scripts / 'test-package-host.sh')],
                    cwd=root, env={**os.environ, 'PATH': str(tools) + ':' + os.environ['PATH'], 'VERDICT': verdict},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

if __name__ == "__main__":
    unittest.main()
