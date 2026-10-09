#!/usr/bin/env python3
"""Manual Simulator playthrough workers, durable evidence, and report generation."""
import argparse
from collections import Counter
from itertools import zip_longest
import hashlib
import html
import json
import math
import statistics
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import time

from internal.playthrough_report import render_agent_preview


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def parse_args():
    parser = argparse.ArgumentParser(prog="./Scripts/playthrough-sweep.sh", description=__doc__)
    parser.add_argument("--products", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--destination", help=argparse.SUPPRESS)
    parser.add_argument("--scenario", type=Path, help="complete scenario.json emitted by a previous career; its settings override CLI defaults")
    parser.add_argument("--seed", type=positive, default=42)
    parser.add_argument("--horizon", type=positive, default=2, help="settled battle attempts per career")
    parser.add_argument("--scenarios", type=positive, default=1)
    parser.add_argument("--full-access", action="store_true")
    parser.add_argument("--mode", choices=["campaign", "spires", "labyrinth", "contracts"], default="campaign")
    parser.add_argument("--policy", choices=["greedy-v1", "setupAware-v1", "random-v1", "rotation-v1"], default="greedy-v1")
    parser.add_argument("--hero", default="knight")
    parser.add_argument("--companion", default="wolf")
    parser.add_argument("--output", type=Path, default=Path("PlaythroughReports") / time.strftime("%Y%m%d-%H%M%S"))
    parser.add_argument("--replay-bundle", type=Path)
    parser.add_argument("--crash-proof", action="store_true", help="interrupt launch before its result is journaled, recover and replay in new workers")
    parser.add_argument("--timeout", type=positive, default=180, help="external per-worker wall-time limit")
    parser.add_argument("--baseline", type=Path, help="prior report.json for paired scenario comparison")
    return parser.parse_args()


def command_output(*command):
    return subprocess.check_output(command, text=True).strip()


def identity():
    diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"])
    for name in command_output("git", "ls-files", "--others", "--exclude-standard").splitlines():
        path = Path(name)
        if path.is_file():
            diff += name.encode() + path.read_bytes()
    return {"commit": command_output("git", "rev-parse", "HEAD"),
            "dirtySHA256": hashlib.sha256(diff).hexdigest(),
            "host": command_output("sw_vers"), "xcode": command_output("xcodebuild", "-version"),
            "swift": command_output("xcrun", "swift", "--version"),
            "simulators": json.loads(command_output("xcrun", "simctl", "list", "devices", "booted", "--json"))}


def configure_worker(template, request, destination):
    data = plistlib.loads(template.read_bytes())
    # Relocate __TESTROOT__ references because each request has a private xctestrun.
    def relocate(value):
        if isinstance(value, str):
            return value.replace("__TESTROOT__", str(template.parent))
        if isinstance(value, list):
            return [relocate(v) for v in value]
        if isinstance(value, dict):
            return {k: relocate(v) for k, v in value.items()}
        return value
    data = relocate(data)
    for config in data["TestConfigurations"]:
        for target in config["TestTargets"]:
            target.setdefault("EnvironmentVariables", {})["TRINKET_PLAYTHROUGH_REQUEST"] = str(request)
            target["ParallelizationEnabled"] = False
    destination.write_bytes(plistlib.dumps(data))


def process_identity(pid):
    result = subprocess.run(["ps", "-p", str(pid), "-o", "lstart=,comm="], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 and "xctest" in result.stdout else None


def stop_worker(process, owned_worker, *, immediate=False):
    if owned_worker and process_identity(owned_worker[0]) == owned_worker[1]:
        try:
            os.kill(owned_worker[0], signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        os.killpg(process.pid, signal.SIGKILL if immediate else signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


def worker(args, template, name, operation="run", source=None, crash_after=None, seed=None, crash_settlement=False, expected=None, crash_before_settlement=False):
    folder = args.output / name
    request = args.output / f"{name}-request.json"
    request.write_text(json.dumps({"operation": operation, "output": str(folder), "seed": seed or args.seed,
                                   "horizon": args.horizon, "fullAccess": args.full_access,
                                   "source": str(source) if source else None, "crashAfter": crash_after,
                                   "mode": args.mode, "policy": args.policy, "hero": args.hero, "companion": args.companion,
                                   "scenarioPath": str(args.scenario.resolve()) if args.scenario else None, "crashSettlement": crash_settlement, "crashBeforeSettlement": crash_before_settlement, "expected": str(expected) if expected else None}))
    runfile = args.output / f"{name}.xctestrun"
    configure_worker(template, request, runfile)
    command = ["xcodebuild", "test-without-building", "-xctestrun", str(runfile),
               "-destination", args.destination, "-parallel-testing-enabled", "NO",
               "-only-testing:TrinketAppStateTests/PlaythroughSweepTests",
               "-resultBundlePath", str(args.output / f"{name}.xcresult")]
    started = time.monotonic()
    with (args.output / f"{name}.log").open("wb") as log:
        owned_worker = None
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = started + args.timeout
            interruption_seen = None
            while process.poll() is None:
                pid_file = folder / "worker-pid.txt"
                if owned_worker is None and pid_file.exists():
                    pid = int(pid_file.read_text())
                    observed = process_identity(pid)
                    if observed:
                        owned_worker = (pid, observed)
                if (folder / "interrupted.json").exists():
                    interruption_seen = interruption_seen or time.monotonic()
                if time.monotonic() >= deadline or (interruption_seen and time.monotonic() - interruption_seen > 10):
                    raise subprocess.TimeoutExpired(command, args.timeout)
                time.sleep(0.1)
            code = process.returncode
            termination = "crash" if code else "missingWorkerResult"
        except subprocess.TimeoutExpired:
            stop_worker(process, owned_worker)
            code, termination = (86, "injectedInterruption") if (folder / "interrupted.json").exists() else (124, "watchdogTimeout")
        except KeyboardInterrupt:
            stop_worker(process, owned_worker, immediate=True)
            raise
    summary_path = folder / "summary.json"
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {"termination": termination}
    if code and summary.get("termination") == "completedObjective":
        summary["termination"] = "workerFailure"
    manifest = folder / "scenario.json"
    if manifest.exists():
        summary["scenarioManifest"] = json.loads(manifest.read_text())
    summary["population"] = "coverage-directed" if args.crash_proof else "replay" if operation == "replay" else "fresh-save"
    summary.update(worker=name, exitCode=code, processWallSeconds=time.monotonic() - started, seed=seed or args.seed)
    print(f"{name}: {summary['termination']} ({summary['processWallSeconds']:.2f}s)", flush=True)
    return summary


def wilson(successes, total):
    if total == 0:
        return None
    z = 1.959963984540054
    proportion = successes / total
    denominator = 1 + z * z / total
    center = (proportion + z * z / (2 * total)) / denominator
    radius = z * math.sqrt(proportion * (1 - proportion) / total + z * z / (4 * total * total)) / denominator
    return {"successes": successes, "careers": total, "proportion": proportion,
            "interval95": [max(0, center - radius), min(1, center + radius)]}


def metric_stats(summaries, key):
    values = [summary[key] for summary in summaries if key in summary]
    if not values:
        return None
    return {"mean": round(statistics.mean(values), 3),
            "median": round(statistics.median(values), 3),
            "min": min(values),
            "max": max(values)}


def percentage(value, total):
    return round(100 * value / total, 1) if total else None


def failure_contexts(summaries):
    grouped = {}
    examples = []
    for summary in summaries:
        for battle in summary.get("battleOutcomes", []):
            if battle.get("outcome") == "victory":
                continue
            encounter = battle.get("encounterID") or "unknown"
            enemy = battle.get("enemyID") or "unknown"
            level = battle.get("enemyEncounterLevel")
            key = (encounter, enemy, level)
            group = grouped.setdefault(key, {"encounterID": encounter, "enemyID": enemy,
                                              "enemyEncounterLevel": level, "failures": 0,
                                              "careers": set(), "attempts": set()})
            group["failures"] += 1
            group["careers"].add(summary.get("seed"))
            if battle.get("attempt") is not None:
                group["attempts"].add(battle["attempt"])
            if len(examples) < 20:
                examples.append({"seed": summary.get("seed"), "attempt": battle.get("attempt"),
                                 "outcome": battle.get("outcome"), "encounterID": encounter,
                                 "enemyID": enemy, "enemyEncounterLevel": level,
                                 "heroLevel": battle.get("heroLevel"), "companionLevel": battle.get("companionLevel"),
                                 "heroTalentCount": battle.get("heroTalentCount"),
                                 "companionTalentCount": battle.get("companionTalentCount"),
                                 "heroEquipmentCount": battle.get("heroEquipmentCount"),
                                 "companionEquipmentCount": battle.get("companionEquipmentCount")})
    contexts = [{"encounterID": group["encounterID"], "enemyID": group["enemyID"],
                 "enemyEncounterLevel": group["enemyEncounterLevel"], "failures": group["failures"],
                 "careers": len(group["careers"]), "attempts": sorted(group["attempts"])}
                for group in grouped.values()]
    contexts.sort(key=lambda context: (-context["failures"], context["encounterID"], context["enemyID"]))
    return contexts, examples


def build_agent_report(args, result):
    workers = result["workers"]
    completed = [summary for summary in workers
                 if summary.get("termination") == "completedObjective" and summary.get("exitCode") == 0]
    outcomes = [outcome for summary in workers for outcome in summary.get("outcomes", [])]
    outcome_counts = Counter(outcomes)
    victories = outcome_counts.get("victory", 0)
    defeats = outcome_counts.get("defeat", 0)
    career_victories = result.get("careersWithVictory") or {"successes": 0, "careers": 0, "proportion": None,
                                                             "interval95": [None, None]}
    stage_reach = Counter(stage for summary in workers for stage in summary.get("reachedStages", []))
    attempt_rates = []
    for index, outcomes_at_attempt in enumerate(zip_longest(*(summary.get("outcomes", []) for summary in workers))):
        slot = [outcome for outcome in outcomes_at_attempt if outcome is not None]
        victories_at_attempt = slot.count("victory")
        attempt_rates.append({"attempt": index + 1, "victories": victories_at_attempt, "settled": len(slot),
                              "proportion": victories_at_attempt / len(slot)})
    outcome_sequences = Counter(" -> ".join(summary.get("outcomes", [])) or "none" for summary in workers)

    metric_keys = ("actions", "turns", "cardsDrawn", "cardsObserved", "playableObservations", "cardsChosen",
                   "goldEarned", "goldSpent", "talents", "equipmentChanges", "upgrades", "reloads",
                   "simulatedSeconds", "wallSeconds", "processWallSeconds", "peakResidentBytes")
    metrics = {key: metric_stats(workers, key) for key in metric_keys}
    total_gold_earned = sum(summary.get("goldEarned", 0) for summary in workers)
    total_gold_spent = sum(summary.get("goldSpent", 0) for summary in workers)
    total_upgrades = sum(summary.get("upgrades", 0) for summary in workers)
    failure_contexts_by_encounter, failure_examples = failure_contexts(workers)
    total_failures = sum(context["failures"] for context in failure_contexts_by_encounter)
    incomplete = result.get("incomplete", 0)
    career_count = len(completed)
    confidence = "high" if career_count >= 50 and incomplete == 0 else "medium" if career_count >= 20 and incomplete == 0 else "low"
    verdict = "insufficient-data" if career_count == 0 else "incomplete-run" if incomplete else "directional-signal"
    comparison_policy = "greedy-v1" if result["policy"] == "setupAware-v1" else "setupAware-v1"
    insights = []
    next_experiments = []
    limitations = [
        "Bot outcomes are diagnostic signals, not player win-rate estimates.",
        "Career-level uncertainty is used; attempts within a career are correlated.",
    ]

    if incomplete:
        insights.append({"id": "incomplete-careers", "severity": "warning", "title": "Some careers did not settle",
                         "observation": f"{incomplete} of {result['planned']} planned careers were incomplete.",
                         "recommendation": "Inspect only the affected career evidence to identify the stopping condition.",
                         "evidence": ["worker summaries"]})
        next_experiments.append("Investigate incomplete careers before treating outcome rates as comparable.")
    elif not career_count:
        insights.append({"id": "no-completed-careers", "severity": "warning", "title": "No completed careers to analyze",
                         "observation": "This run produced no completed career cohort.",
                         "recommendation": "Treat the run as lifecycle or recovery evidence and inspect only the relevant worker evidence.",
                         "evidence": ["worker summaries"]})
    else:
        insights.append({"id": "complete-cohort", "severity": "info", "title": "Cohort completed cleanly",
                         "observation": f"All {career_count} completed careers reached their configured objective.",
                         "recommendation": "Use the cohort for aggregate comparisons; retain raw evidence for targeted failures only.",
                         "evidence": ["worker summaries"]})

    if career_count < 20:
        limitations.append("The career sample is below the 20-career directional threshold.")
        next_experiments.append("Run at least 20 careers before making a balance claim.")
    elif career_count < 50:
        limitations.append("The cohort supports directional comparison, but confidence intervals remain broad.")
        next_experiments.append("Repeat with 50 or more careers when a tighter estimate is needed.")

    if career_count:
        career_rate = percentage(career_victories.get("successes", 0), career_count)
        interval = career_victories.get("interval95", [None, None])
        interval_text = f" ({round(interval[0] * 100, 1)}–{round(interval[1] * 100, 1)}% 95% interval)" if interval[0] is not None else ""
        policy_comparison_available = result.get("baselinePolicy") == comparison_policy
        insights.append({"id": "career-outcomes", "severity": "info", "title": "Career outcome signal",
                         "observation": f"{career_victories.get('successes', 0)} of {career_count} careers reached at least one victory ({career_rate}%){interval_text}.",
                         "recommendation": "Use the paired policy result in this report before attributing the result to balance." if policy_comparison_available else "Compare the same seed population with another policy before attributing the result to balance.",
                         "evidence": ["career-level outcome counts"]})
        if not policy_comparison_available:
            next_experiments.append(f"Run the same seed cohort with {comparison_policy} for a policy comparison.")

    if len(attempt_rates) >= 2 and all(rate["settled"] for rate in attempt_rates[:2]):
        first, second = attempt_rates[:2]
        delta = second["proportion"] - first["proportion"]
        if abs(delta) >= 0.1:
            direction = "higher" if delta > 0 else "lower"
            retry_recommendation = ("Inspect persistent progression across attempts; the horizon and paired policy comparison are already present."
                                    if result["horizon"] >= 10 and result.get("baselinePolicy") == comparison_policy else
                                    "Confirm whether persistence or retry progression drives this pattern with a longer horizon and a comparison policy.")
            insights.append({"id": "retry-delta", "severity": "info", "title": "Retry outcomes differ from first attempts",
                             "observation": f"Attempt two was {abs(round(delta * 100, 1))} percentage points {direction} than attempt one ({round(first['proportion'] * 100, 1)}% vs {round(second['proportion'] * 100, 1)}%).",
                             "recommendation": retry_recommendation,
                             "evidence": ["attempt-position outcome counts"]})
            if result["horizon"] < 10:
                next_experiments.append("Use a longer horizon to separate retry progression from seed variance.")

    largest_regression = None
    prior_peak = None
    for rate in attempt_rates:
        if not rate["settled"]:
            break
        if prior_peak is not None:
            delta = rate["proportion"] - prior_peak["proportion"]
            if delta <= -0.1 and (largest_regression is None or delta < largest_regression["delta"]):
                largest_regression = {"attempt": rate["attempt"], "priorPeak": prior_peak["attempt"], "delta": delta,
                                      "currentRate": rate["proportion"], "priorRate": prior_peak["proportion"]}
        if prior_peak is None or rate["proportion"] > prior_peak["proportion"]:
            prior_peak = rate
    if largest_regression:
        regression_recommendation = ("Inspect progression or encounter changes around the regression point; the paired policy comparison is already present."
                                     if result.get("baselinePolicy") == comparison_policy else
                                     "Compare the same horizon with the opposite policy and inspect progression or encounter changes around the regression point.")
        insights.append({"id": "attempt-regression", "severity": "warning", "title": "Late-run outcome regression",
                         "observation": f"Attempt {largest_regression['attempt']} fell {round(abs(largest_regression['delta']) * 100, 1)} percentage points from the prior peak at attempt {largest_regression['priorPeak']} ({round(largest_regression['priorRate'] * 100, 1)}% to {round(largest_regression['currentRate'] * 100, 1)}%).",
                         "recommendation": regression_recommendation,
                         "evidence": ["full attempt-position outcome trajectory"]})

    if failure_contexts_by_encounter:
        top_context = failure_contexts_by_encounter[0]
        insights.append({"id": "failure-context", "severity": "info", "title": "Failure contexts are available without raw journals",
                         "observation": f"{total_failures} non-victory outcomes are grouped by encounter and enemy; the most frequent context is {top_context['encounterID']} against {top_context['enemyID']} ({top_context['failures']} failures).",
                         "recommendation": "Inspect the listed encounter and enemy IDs first, then retrieve only matching career evidence if needed.",
                         "evidence": ["metrics.battleFailures.byContext"]})

    if total_gold_spent == 0 and total_upgrades == 0:
        insights.append({"id": "economy-unexercised", "severity": "warning", "title": "Economy was not exercised",
                         "observation": f"The cohort earned {total_gold_earned} Gold but spent none and made no Homestead upgrades.",
                         "recommendation": "Use a longer horizon or setupAware-v1 before drawing economy conclusions.",
                         "evidence": ["aggregate Gold and upgrade counters"]})
        if result["horizon"] < 10:
            next_experiments.append("Run 10 or more attempts with setupAware-v1 to exercise spending and Homestead progression.")
        else:
            next_experiments.append("Inspect the current policy's economy decisions; this horizon should have exercised spending or Homestead progression.")

    peak_memory = metrics.get("peakResidentBytes")
    if peak_memory and peak_memory["max"] > 512 * 1024 * 1024:
        insights.append({"id": "memory-budget", "severity": "warning", "title": "Worker memory exceeded advisory budget",
                         "observation": f"Peak resident memory reached {round(peak_memory['max'] / 1024 / 1024, 1)} MiB.",
                         "recommendation": "Inspect the worker with the highest peak before increasing cohort size.",
                         "evidence": ["worker memory metrics"]})
    elif peak_memory:
        insights.append({"id": "runtime-health", "severity": "info", "title": "Runtime health stayed within advisory bounds",
                         "observation": f"Peak resident memory stayed at or below {round(peak_memory['max'] / 1024 / 1024, 1)} MiB, under the 512 MiB advisory budget.",
                         "recommendation": "Continue monitoring memory as horizon and content coverage increase.",
                         "evidence": ["worker memory metrics"]})

    paired = result.get("pairedComparison")
    paired_summary = None
    if paired:
        effect = result.get("goldEarnedEffect", {})
        mean_delta = effect.get("meanDelta")
        before_career_victories = sum("victory" in comparison.get("before", []) for comparison in paired)
        after_career_victories = sum("victory" in comparison.get("after", []) for comparison in paired)
        before_attempt_victories = sum(comparison.get("before", []).count("victory") for comparison in paired)
        after_attempt_victories = sum(comparison.get("after", []).count("victory") for comparison in paired)
        transitions = {}
        for comparison in paired:
            transition = " -> ".join((", ".join(comparison.get("before", [])) or "none",
                                       ", ".join(comparison.get("after", [])) or "none"))
            transitions[transition] = transitions.get(transition, 0) + 1
        paired_summary = {"careers": len(paired), "beforePolicy": result.get("baselinePolicy", result["policy"]),
                          "afterPolicy": result["policy"],
                          "careerVictories": {"before": before_career_victories, "after": after_career_victories},
                          "attemptVictories": {"before": before_attempt_victories, "after": after_attempt_victories},
                          "outcomeTransitions": transitions,
                          "goldEarnedEffect": effect}
        is_policy_comparison = result.get("baselinePolicy") not in (None, result["policy"])
        title = "Paired policy comparison available" if is_policy_comparison else "Paired baseline comparison available"
        policy_text = f"{result['baselinePolicy']} to {result['policy']}; " if is_policy_comparison else ""
        insights.append({"id": "baseline-comparison", "severity": "info", "title": title,
                         "observation": f"Compared {len(paired)} identical seed careers ({policy_text}career victories {before_career_victories} to {after_career_victories}, attempt victories {before_attempt_victories} to {after_attempt_victories}); mean Gold delta was {mean_delta}.",
                         "recommendation": "Use paired outcomes and Gold deltas together; do not infer causality from a single cohort.",
                         "evidence": ["pairedComparison", "goldEarnedEffect"]})

    return {
        "schemaVersion": 1,
        "source": "report.json",
        "experiment": {**{key: result[key] for key in ("planned", "horizon", "fullAccess", "mode", "policy", "hero", "companion")},
                       "baselinePolicy": result.get("baselinePolicy")},
        "verdict": verdict,
        "confidence": confidence,
        "metrics": {
            "careers": {"planned": result["planned"], "completed": career_count, "incomplete": incomplete},
            "outcomes": {"careersWithVictory": career_victories, "attemptsSettled": len(outcomes),
                         "victories": victories, "defeats": defeats, "attemptVictoryRate": victories / len(outcomes) if outcomes else None,
                         "byAttempt": attempt_rates, "sequences": outcome_sequences},
            "stageReachCounts": stage_reach,
            "economy": {"goldEarned": total_gold_earned, "goldSpent": total_gold_spent, "homesteadUpgrades": total_upgrades},
            "battleFailures": {"total": total_failures, "byContext": failure_contexts_by_encounter, "examples": failure_examples},
            "workerMetrics": metrics,
            "pairedComparison": paired_summary,
        },
        "insights": insights,
        "limitations": limitations,
        "nextExperiments": list(dict.fromkeys(next_experiments)),
        "rawEvidence": {"available": True, "included": False,
                        "retrieval": "Request a named career and bounded evidence range for forensic debugging."},
    }


def baseline_workers(baseline, current):
    """Validate recorded scenario evidence before matching careers by seed."""
    if not isinstance(baseline, dict) or any(
        baseline.get(key) != current[key] for key in ("horizon", "fullAccess", "mode", "hero", "companion")
    ):
        raise ValueError("baseline manifest does not match horizon/access/mode/party")
    # These are the persisted inputs to PlaythroughScenario; partial records
    # cannot prove that the two careers ran the same experiment.
    required = ("version", "worldSeed", "combatSeed", "policySeed", "heroID", "companionID",
                "fullAccess", "attempts", "maxActions", "maxTurns", "maxSteps", "maxArtifactBytes",
                "startDate", "policy", "mode", "invest", "sessionSeconds")
    populations = []
    for report in (baseline, current):
        workers = report.get("workers")
        if not isinstance(workers, list):
            raise ValueError("baseline must have a unique seed population")
        indexed = {}
        for worker in workers:
            seed = worker.get("seed") if isinstance(worker, dict) else None
            if type(seed) is not int or seed in indexed:
                raise ValueError("baseline must have a unique seed population")
            manifest = worker.get("scenarioManifest")
            if not isinstance(manifest, dict) or any(manifest.get(key) is None for key in required):
                raise ValueError("baseline requires complete scenario manifests")
            if (type(manifest["version"]) is not int or manifest["version"] != 1
                or type(manifest["worldSeed"]) is not int or manifest["worldSeed"] != seed
                or any(manifest[key] != report.get(setting) for key, setting in (
                    ("attempts", "horizon"), ("fullAccess", "fullAccess"), ("mode", "mode"),
                    ("heroID", "hero"), ("companionID", "companion"), ("policy", "policy")
                ))):
                raise ValueError("baseline scenario manifests must match the recorded experiment")
            indexed[seed] = worker
        populations.append(indexed)
    old, new = populations
    if old.keys() != new.keys() or any(
        {key: value for key, value in old[seed]["scenarioManifest"].items() if key != "policy"}
        != {key: value for key, value in new[seed]["scenarioManifest"].items() if key != "policy"}
        for seed in old
    ):
        raise ValueError("baseline must have identical scenario manifests and seed population")
    return old


def report(args, summaries, host):
    result = {"schemaVersion": 1, "identity": host, "planned": 0 if args.crash_proof or args.replay_bundle else args.scenarios,
              "horizon": args.horizon, "fullAccess": args.full_access, "mode": args.mode, "policy": args.policy,
              "hero": args.hero, "companion": args.companion, "workers": summaries}
    completed = [s for s in summaries if s.get("termination") == "completedObjective" and s["exitCode"] == 0]
    result["completed"] = len(completed)
    result["careersWithVictory"] = wilson(sum("victory" in s.get("outcomes", []) for s in completed), len(completed))
    result["incomplete"] = sum(s.get("termination") not in {"completedObjective", "replayedRecordedActions",
                               "replayedUnknownOutcome", "recoveredCapturedStore"} for s in summaries)
    if args.baseline:
        baseline = json.loads(args.baseline.read_text())
        old = baseline_workers(baseline, result)
        result["baselinePolicy"] = baseline.get("policy")
        result["pairedComparison"] = [{"seed": s["seed"], "before": old[s["seed"]].get("outcomes", []),
                                       "after": s.get("outcomes", []),
                                       "goldEarnedDelta": s.get("goldEarned", 0) - old[s["seed"]].get("goldEarned", 0)}
                                      for s in summaries]
        deltas = [pair["goldEarnedDelta"] for pair in result["pairedComparison"]]
        result["goldEarnedEffect"] = {"pairedCareers": len(deltas), "meanDelta": statistics.mean(deltas) if deltas else None,
                                     "standardError": statistics.stdev(deltas) / math.sqrt(len(deltas)) if len(deltas) > 1 else None}
    (args.output / "report.json").write_text(json.dumps(result, indent=2))
    agent_report = build_agent_report(args, result)
    (args.output / "report-agent.json").write_text(json.dumps(agent_report, indent=2))
    (args.output / "report-agent.md").write_text(render_agent_preview(agent_report))
    rows = "".join(f"<tr><td>{html.escape(s['worker'])}</td><td>{s['seed']}</td><td>{html.escape(s['termination'])}</td>"
                   f"<td>{html.escape(', '.join(s.get('outcomes', [])))}</td><td>{s.get('talents', 0)} / {s.get('equipmentChanges', 0)} / {s.get('upgrades', 0)}</td><td>{s['processWallSeconds']:.2f}</td></tr>" for s in summaries)
    insights = "".join(f"<li><strong>{html.escape(item['title'])}:</strong> {html.escape(item['observation'])} {html.escape(item['recommendation'])}</li>"
                       for item in agent_report["insights"])
    next_experiments = "".join(f"<li>{html.escape(experiment)}</li>" for experiment in agent_report["nextExperiments"])
    (args.output / "report.html").write_text("<!doctype html><meta charset='utf-8'><title>Trinket playthroughs</title>"
        "<style>body{font:16px system-ui;margin:3rem;max-width:1100px}td,th{text-align:left;padding:.6rem;border-bottom:1px solid #bbb}li{margin:.5rem 0}</style>"
        "<h1>Trinket playthroughs</h1><p>Manual diagnostic data. Bot outcomes are not player win-rate estimates.</p>"
        f"<p>Planned {result['planned']}; completed {result['completed']}; incomplete {result['incomplete']}.</p>"
        f"<h2>Actionable insights</h2><ul>{insights}</ul>"
        f"<h2>Next experiments</h2><ul>{next_experiments or '<li>None generated.</li>'}</ul>"
        "<table><tr><th>Worker</th><th>Seed</th><th>Termination</th><th>Outcomes</th><th>Talents / equips / upgrades</th><th>Wall seconds</th></tr>" + rows + "</table>")
    return result


def interrupt_run(_signal, _frame):
    raise KeyboardInterrupt


def run_sweep(args):
    if not args.products or not args.destination:
        raise SystemExit("Use Scripts/playthrough-sweep.sh to acquire the managed Simulator lease.")
    manifest_path = args.scenario or (args.replay_bundle / "scenario.json" if args.replay_bundle else None)
    if manifest_path:
        manifest = json.loads(manifest_path.read_text())
        args.seed, args.horizon = manifest["worldSeed"], manifest["attempts"]
        args.full_access, args.mode, args.policy = manifest["fullAccess"], manifest["mode"], manifest["policy"]
        args.hero, args.companion = manifest["heroID"], manifest["companionID"]
    if args.seed + args.scenarios >= 2**64 or args.horizon > 1000 or args.scenarios > 1000:
        raise SystemExit("seed must fit UInt64; horizon and scenarios must be <= 1000")
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    if getattr(args, 'retention_root', None) is not None:
        from internal.output_retention import begin
        begin(args.output, args.retention_root, os.getpid())
        if os.environ.get('TRINKET_KEEP_REPORTS') == '1':
            (args.output / '.retention-keep').touch()
    template = max(args.products.resolve().glob("*.xctestrun"), key=lambda p: p.stat().st_mtime)
    host = identity()
    (args.output / "identity.json").write_text(json.dumps(host, indent=2))
    summaries = []
    if args.crash_proof:
        summaries.append(worker(args, template, "interrupted", crash_after=3))
        source = args.output / "interrupted"
        archive = args.output / "interrupted-archive"
        shutil.copytree(source, archive)
        summaries.append(worker(args, template, "recovery", "recover", archive))
        summaries.append(worker(args, template, "replay", "replay", archive))
        summaries.append(worker(args, template, "before-settlement-interrupted", crash_before_settlement=True))
        before_archive = args.output / "before-settlement-archive"
        shutil.copytree(args.output / "before-settlement-interrupted", before_archive)
        summaries.append(worker(args, template, "before-settlement-recovery", "recover", before_archive,
                                expected=before_archive / "pre-settlement-save.json"))
        summaries.append(worker(args, template, "before-settlement-replay", "replay", before_archive))
        summaries.append(worker(args, template, "cloud-interrupted", "cloud-crash"))
        cloud_archive = args.output / "cloud-archive"
        shutil.copytree(args.output / "cloud-interrupted", cloud_archive)
        summaries.append(worker(args, template, "cloud-recovery", "cloud-recover", cloud_archive))
        summaries.append(worker(args, template, "settlement-interrupted", crash_settlement=True))
        settlement_archive = args.output / "settlement-archive"
        shutil.copytree(args.output / "settlement-interrupted", settlement_archive)
        summaries.append(worker(args, template, "settlement-replay", "replay", settlement_archive))
        summaries.append(worker(args, template, "settlement-recovery", "recover", settlement_archive,
                                expected=args.output / "settlement-replay" / "final-save.json"))
    elif args.replay_bundle:
        summaries.append(worker(args, template, "replay", "replay", args.replay_bundle.resolve()))
    else:
        for index in range(args.scenarios):
            summaries.append(worker(args, template, f"career-{index:04}", seed=args.seed + index))
    report(args, summaries, host)
    print(f"Report: {args.output / 'report.html'}")
    print(f"Agent summary: {args.output / 'report-agent.md'}")
    if args.crash_proof:
        success = all((args.output / name / "interrupted.json").exists() for name in ("interrupted", "before-settlement-interrupted", "cloud-interrupted", "settlement-interrupted")) and all(
            s["exitCode"] == 0 and s["termination"] in {"recoveredCapturedStore", "replayedUnknownOutcome", "cloudProcessRecovered"}
            for s in summaries if s["worker"] not in {"interrupted", "before-settlement-interrupted", "cloud-interrupted", "settlement-interrupted"})
    else:
        success = all(s["exitCode"] == 0 and s["termination"] in {"completedObjective", "replayedRecordedActions", "reproducedFailure"} for s in summaries)
    return 0 if success else 1


def main():
    from internal.cli import ROOT
    from internal import output_retention as retention
    args = parse_args()
    signal.signal(signal.SIGTERM, interrupt_run)
    # Keep an explicitly supplied baseline/replay bundle through this comparison.
    inputs = [p for p in (args.baseline, args.replay_bundle, args.scenario) if p is not None]
    pins = []
    for source in inputs:
        source = source.resolve()
        if retention.managed_path(source, ROOT):
            keep = retention.marker(source, retention.KEEP)
            if not keep.exists():
                keep.touch()
                pins.append(keep)
    path = args.output.absolute()
    owned = retention.managed_path(path, ROOT)
    status = 1
    try:
        retention.cleanup(ROOT, apply=True)
        # The output directory is created by run_sweep; take ownership immediately
        # after creation, before any long-running worker or product query.
        args.retention_root = ROOT if owned else None
        status = run_sweep(args)
        return status
    finally:
        if owned and retention.marker(path, retention.OWNER).exists():
            retention.finish(path, ROOT, os.getpid(), status, comparison=True)
        for keep in pins:
            keep.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
