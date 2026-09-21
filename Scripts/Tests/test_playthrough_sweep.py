"""Regression checks for playthrough evidence and report acceptance."""

SCRIPT_INPUTS = (
    'Scripts/playthrough-sweep.sh',
    'Scripts/playthrough_sweep.py',
    'Scripts/internal/playthrough_report.py',
)

import json
from pathlib import Path
import plistlib
import tempfile
from types import SimpleNamespace
import unittest

from script_test_support import load_script

MODULE = load_script("playthrough_sweep", "playthrough_sweep.py")


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
            agent_report = json.loads((args.output / "report-agent.json").read_text())
            self.assertEqual(agent_report["verdict"], "incomplete-run")
            self.assertIn("insights", agent_report)
            self.assertNotIn("workers", agent_report)
            self.assertFalse(agent_report["rawEvidence"]["included"])
            args.baseline = args.output / "baseline.json"
            bad = dict(result, horizon=3)
            args.baseline.write_text(json.dumps(bad))
            with self.assertRaisesRegex(ValueError, "baseline manifest"):
                MODULE.report(args, workers, {})

    def test_agent_report_derives_retry_and_economy_actions(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=2, horizon=2,
                                   full_access=False, mode="campaign", policy="greedy-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker="first", seed=42, termination="completedObjective", exitCode=0,
                            outcomes=["defeat", "victory"], processWallSeconds=1.0),
                       dict(worker="second", seed=43, termination="completedObjective", exitCode=0,
                            outcomes=["victory", "victory"], processWallSeconds=1.0)]
            MODULE.report(args, workers, {})
            agent_report = json.loads((args.output / "report-agent.json").read_text())
            insight_ids = {insight["id"] for insight in agent_report["insights"]}
            self.assertIn("retry-delta", insight_ids)
            self.assertIn("economy-unexercised", insight_ids)
            self.assertEqual(agent_report["metrics"]["outcomes"]["attemptsSettled"], 4)

    def test_agent_report_flags_late_regression_and_avoids_recommending_current_experiment(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=1, horizon=10,
                                   full_access=False, mode="campaign", policy="setupAware-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker="long", seed=42, termination="completedObjective", exitCode=0,
                            outcomes=["victory"] * 9 + ["defeat"], processWallSeconds=1.0)]
            MODULE.report(args, workers, {})
            agent_report = json.loads((args.output / "report-agent.json").read_text())
            insight_ids = {insight["id"] for insight in agent_report["insights"]}
            self.assertIn("attempt-regression", insight_ids)
            self.assertIn("greedy-v1", " ".join(agent_report["nextExperiments"]))
            self.assertNotIn("setupAware-v1", " ".join(agent_report["nextExperiments"]))
            self.assertNotIn("Use a longer horizon", " ".join(agent_report["nextExperiments"]))

    def test_report_allows_cross_policy_baseline(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=2, horizon=10,
                                   full_access=False, mode="campaign", policy="setupAware-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker="first", seed=42, termination="completedObjective", exitCode=0,
                            outcomes=["defeat", "victory"] + ["victory"] * 8, processWallSeconds=1.0),
                       dict(worker="second", seed=43, termination="completedObjective", exitCode=0,
                            outcomes=["victory"] * 10, processWallSeconds=1.0)]
            baseline = dict(MODULE.report(args, workers, {}), policy="greedy-v1")
            baseline_path = Path(temporary) / "baseline.json"
            baseline_path.write_text(json.dumps(baseline))
            args.baseline = baseline_path
            result = MODULE.report(args, workers, {})
            self.assertEqual(result["baselinePolicy"], "greedy-v1")
            agent_report = json.loads((args.output / "report-agent.json").read_text())
            paired = agent_report["metrics"]["pairedComparison"]
            self.assertEqual((paired["beforePolicy"], paired["afterPolicy"]), ("greedy-v1", "setupAware-v1"))
            self.assertEqual(agent_report["insights"][-1]["title"], "Paired policy comparison available")
            recommendations = " ".join(agent_report["nextExperiments"])
            self.assertNotIn("Run the same seed cohort with greedy-v1", recommendations)
            self.assertNotIn("Run the same seed cohort with setupAware-v1", recommendations)
            retry_insight = next(insight for insight in agent_report["insights"] if insight["id"] == "retry-delta")
            self.assertNotIn("longer horizon", retry_insight["recommendation"])

    def test_agent_report_groups_failure_context_without_raw_journal(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=1, horizon=2,
                                   full_access=False, mode="campaign", policy="greedy-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker="failure", seed=42, termination="completedObjective", exitCode=0,
                            outcomes=["defeat", "victory"], processWallSeconds=1.0,
                            battleOutcomes=[{"attempt": 1, "outcome": "defeat", "encounterID": "chapter-2-stage-10",
                                             "enemyID": "enemy-warden", "enemyEncounterLevel": 12,
                                             "heroLevel": 5, "companionLevel": 5, "heroTalentCount": 2,
                                             "companionTalentCount": 1, "heroEquipmentCount": 3,
                                             "companionEquipmentCount": 2}])]
            MODULE.report(args, workers, {})
            agent_report = json.loads((args.output / "report-agent.json").read_text())
            failures = agent_report["metrics"]["battleFailures"]
            self.assertEqual(failures["total"], 1)
            self.assertEqual(failures["byContext"][0]["encounterID"], "chapter-2-stage-10")
            self.assertEqual(failures["examples"][0]["enemyID"], "enemy-warden")
            self.assertEqual(failures["examples"][0]["heroLevel"], 5)
            self.assertFalse(agent_report["rawEvidence"]["included"])

    def test_large_preview_preserves_complete_analysis_and_late_warning(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = SimpleNamespace(output=Path(temporary), scenarios=30, horizon=100,
                                   full_access=True, mode="campaign", policy="setupAware-v1", hero="knight", companion="wolf",
                                   baseline=None, crash_proof=False, replay_bundle=None)
            workers = [dict(worker=f"career-{seed}", seed=seed, termination="completedObjective", exitCode=0,
                            outcomes=["victory"] * 99 + ["defeat"], processWallSeconds=1.0,
                            battleOutcomes=[dict(attempt=100, outcome="defeat", encounterID=f"stage-{seed}",
                                                 enemyID="warden", enemyEncounterLevel=100)]) for seed in range(30)]
            MODULE.report(args, workers, {})
            preview = (args.output / "report-agent.md").read_text()
            analysis = json.loads((args.output / "report-agent.json").read_text())
            self.assertLessEqual(len(preview), 12_000)
            self.assertIn("Late-run outcome regression", preview)
            self.assertIn("Attempt 100", preview)
            self.assertLess(preview.index("Late-run outcome regression"), preview.index("Cohort completed cleanly"))
            self.assertIn("showing 5 of 30; 25 omitted", preview)
            self.assertIn("showing 5 of 20; 15 omitted", preview)
            self.assertEqual(len(analysis["metrics"]["outcomes"]["byAttempt"]), 100)
            self.assertEqual(len(analysis["metrics"]["battleFailures"]["byContext"]), 30)
            self.assertEqual(json.loads((args.output / "report.json").read_text())["workers"], workers)

            # Exercise both field shortening and block omission without changing
            # the complete analysis or allowing info findings to displace warnings.
            analysis["insights"] += [dict(severity="info", title=f"Detail {index}", observation="x" * 2000,
                                          recommendation="Inspect complete evidence.") for index in range(100)]
            before = json.dumps(analysis)
            oversized = MODULE.render_agent_preview(analysis)
            self.assertLessEqual(len(oversized), 12_000)
            self.assertIn("Late-run outcome regression", oversized)
            self.assertIn("[field shortened]", oversized)
            self.assertNotIn("Preview omissions: 0 blocks", oversized)
            self.assertIn("[Complete analysis](report-agent.json)", oversized)
            self.assertEqual(json.dumps(analysis), before)


if __name__ == "__main__":
    unittest.main()
