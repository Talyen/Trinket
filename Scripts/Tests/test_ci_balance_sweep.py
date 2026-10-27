import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class BalanceCIDiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'Scripts').mkdir()
        (self.root / 'bin').mkdir()
        shutil.copy(ROOT / 'Scripts/ci-balance-sweep.sh', self.root / 'Scripts')
        self.make_executable('bin/git', '#!/bin/bash\necho revision123\n')
        self.make_executable('bin/swift', '#!/bin/bash\necho Swift-test\n')
        self.make_executable('Scripts/balance-sweep.sh', '''#!/bin/bash
printf '%s\\n' "$@" > invocation.txt
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --output-dir ]]; then output="$2"; shift; fi
  shift
done
if [[ "${FAKE_REPORTS:-yes}" == yes ]]; then
  touch "$output/findings.md" "$output/findings.json"
fi
exit "${FAKE_EXIT:-0}"
''')
        self.env = {**os.environ, 'PATH': f"{self.root / 'bin'}:{os.environ['PATH']}"}
        for key in ('BALANCE_MODE', 'BALANCE_TIER', 'BALANCE_SAMPLES', 'BALANCE_SEED'):
            self.env.pop(key, None)

    def make_executable(self, name, contents):
        path = self.root / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_diagnostic(self, **env):
        return subprocess.run([str(self.root / 'Scripts/ci-balance-sweep.sh')],
                              env={**self.env, **env}, text=True, capture_output=True)

    def test_defaults_and_explicit_parameters_reach_sweep_and_metadata(self):
        default = self.run_diagnostic()
        self.assertEqual(default.returncode, 0, default.stderr)
        args = (self.root / 'invocation.txt').read_text().splitlines()
        self.assertEqual(args[:4], ['--mode', 'identity', '--jobs', '2'])
        self.assertNotIn('--samples', args)
        self.assertNotIn('--tiers', args)
        self.assertNotIn('--seed', args)
        result = self.run_diagnostic(BALANCE_MODE='ability-contrast', BALANCE_TIER='lateGame',
                                     BALANCE_SAMPLES='512', BALANCE_SEED='4294967295')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.root / 'invocation.txt').read_text().splitlines()
        self.assertEqual(args[-6:], ['--tiers', 'lateGame', '--samples', '512', '--seed', '4294967295'])
        infos = list((self.root / '.DerivedData/BalanceSweepResults').glob('*/run-info.txt'))
        self.assertEqual(len(infos), 2)
        self.assertTrue(any('Revision: revision123\nMode: ability-contrast' in p.read_text()
                            and 'Swift-test' in p.read_text() for p in infos))

    def test_invalid_inputs_are_rejected_before_invocation(self):
        for env in ({'BALANCE_MODE': 'bad'}, {'BALANCE_TIER': 'bad'},
                    {'BALANCE_SAMPLES': '0'}, {'BALANCE_SAMPLES': '513'},
                    {'BALANCE_SAMPLES': '01'}, {'BALANCE_SEED': '-1'},
                    {'BALANCE_SEED': '4294967296'}, {'BALANCE_SEED': '1; touch injected'}):
            with self.subTest(env=env):
                result = self.run_diagnostic(**env)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse((self.root / 'invocation.txt').exists())

    def test_failure_or_missing_report_fails_even_after_a_previous_success(self):
        self.assertEqual(self.run_diagnostic().returncode, 0)
        self.assertNotEqual(self.run_diagnostic(FAKE_REPORTS='no').returncode, 0)
        self.assertEqual(self.run_diagnostic(FAKE_EXIT='7').returncode, 7)


if __name__ == '__main__':
    unittest.main()
