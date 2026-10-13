
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from script_test_support import write_executable

ROOT = Path(__file__).resolve().parents[2]


class BalanceReportRetentionTests(unittest.TestCase):
    def test_help_and_success_preserve_existing_reports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Scripts").mkdir()
            wrapper = root / "Scripts" / "balance-sweep.sh"
            shutil.copy2(ROOT / "Scripts" / "balance-sweep.sh", wrapper)
            for name in ('cleanup-outputs.py', 'internal/output_retention.py', 'internal/cli.py',
                         'lib/output-retention.sh', 'lib/lock.sh'):
                target = root / 'Scripts' / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / 'Scripts' / name, target)
            tools = root / "bin"
            tools.mkdir()
            write_executable(tools / "swift", "#!/bin/sh\nexit 0\n")
            reports = root / "BalanceSweepReports"
            reports.mkdir()
            evidence = reports / "previous.json"
            evidence.write_text("retained evidence")
            env = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}")
            env.pop("BALANCE_SWEEP_OUTPUT_DIR", None)
            env.pop("TRINKET_KEEP_REPORTS", None)
            for args in (["--help"], ["--samples", "1"]):
                with self.subTest(args=args):
                    subprocess.run([str(wrapper), *args], env=env, check=True, capture_output=True)
                    self.assertEqual(evidence.read_text(), "retained evidence")


if __name__ == "__main__":
    unittest.main()
