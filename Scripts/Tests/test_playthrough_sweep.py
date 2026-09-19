"""Regression checks for playthrough evidence and report acceptance."""
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
from types import SimpleNamespace
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "playthrough_sweep.py"
SPEC = importlib.util.spec_from_file_location("playthrough_sweep", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PlaythroughSweepTests(unittest.TestCase):
    def test_worker_configuration_relocates_products_and_passes_request(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            template = root / "template.xctestrun"
            template.write_bytes(plistlib.dumps({"TestConfigurations": [{"TestTargets": [{
                "TestBundlePath": "__TESTROOT__/Debug/bundle.xctest"}]}]}))
            output = root / "worker.xctestrun"
            request = root / "request.json"
            MODULE.configure_worker(template, request, output)
            target = plistlib.loads(output.read_bytes())["TestConfigurations"][0]["TestTargets"][0]
            self.assertEqual(target["TestBundlePath"], str(root / "Debug/bundle.xctest"))
            self.assertEqual(target["EnvironmentVariables"]["TRINKET_PLAYTHROUGH_REQUEST"], str(request))
            self.assertFalse(target["ParallelizationEnabled"])

    def test_uncertainty_uses_careers_and_handles_empty_population(self):
        self.assertIsNone(MODULE.wilson(0, 0))
        single = MODULE.wilson(1, 1)
        self.assertAlmostEqual(single["interval95"][0], 0.2065493144)
        self.assertAlmostEqual(single["interval95"][1], 1)

    def test_report_keeps_incomplete_and_zero_milestones(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=2, horizon=2,
                                   full_access=False, mode="campaign", policy="greedy-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker="first", seed=42, termination="completedObjective", exitCode=0,
                            outcomes=["victory", "defeat"], processWallSeconds=1.0),
                       dict(worker="second", seed=43, termination="budgetExhaustion", exitCode=65,
                            outcomes=["defeat"], processWallSeconds=2.0)]
            result = MODULE.report(args, workers, {})
            self.assertEqual((result["planned"], result["completed"], result["incomplete"]), (2, 1, 1))
            self.assertEqual(result["careersWithVictory"]["careers"], 1)
            self.assertIn("0 / 0 / 0", (args.output / "report.html").read_text())
            args.baseline = args.output / "baseline.json"
            bad = dict(result, horizon=3)
            args.baseline.write_text(json.dumps(bad))
            with self.assertRaisesRegex(ValueError, "baseline manifest"):
                MODULE.report(args, workers, {})


if __name__ == "__main__":
    unittest.main()
