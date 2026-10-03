"""Prevent malformed invocation evidence from producing a successful CI summary."""

SCRIPT_INPUTS = ('Scripts/ci-diagnostics.py',)

import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import tempfile
import unittest

from script_test_support import load_script

DIAGNOSTICS = load_script('quality_ci_diagnostics', 'ci-diagnostics.py')


class CIDiagnosticsTests(unittest.TestCase):
    def test_malformed_exit_codes_cannot_prove_a_successful_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / 'build-invocation.json'
            output = root / 'aggregate.json'
            for code, passed in ((0, True), ('0', True), (False, False), (0.5, False),
                                 (None, False), (float('inf'), False)):
                with self.subTest(exit_code=code), redirect_stdout(io.StringIO()):
                    manifest.write_text(json.dumps(dict(action='build', status='passed', exit_code=code,
                                                        completion_source='process-exit')))
                    DIAGNOSTICS.main([str(root), str(output)], environ={})
                    report = json.loads(output.read_text())
                    self.assertEqual(report['category'] == 'passed', passed)
                    self.assertEqual(report['failed_invocations'], 0 if passed else 1)


if __name__ == '__main__':
    unittest.main()
