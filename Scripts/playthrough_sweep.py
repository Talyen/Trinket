#!/usr/bin/env python3
"""Manual Simulator playthrough workers, durable evidence, and report generation."""
import argparse
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


def worker(args, template, name, operation="run", source=None, crash_after=None, seed=None, crash_settlement=False, expected=None):
    folder = args.output / name
    request = args.output / f"{name}-request.json"
    request.write_text(json.dumps({"operation": operation, "output": str(folder), "seed": seed or args.seed,
                                   "horizon": args.horizon, "fullAccess": args.full_access,
                                   "source": str(source) if source else None, "crashAfter": crash_after,
                                   "mode": args.mode, "policy": args.policy, "hero": args.hero, "companion": args.companion,
                                   "scenarioPath": str(args.scenario.resolve()) if args.scenario else None, "crashSettlement": crash_settlement, "expected": str(expected) if expected else None}))
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
            if owned_worker and process_identity(owned_worker[0]) == owned_worker[1]:
                try:
                    os.kill(owned_worker[0], signal.SIGKILL)
                except ProcessLookupError:
                    pass
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            code, termination = (86, "injectedInterruption") if (folder / "interrupted.json").exists() else (124, "watchdogTimeout")
        except KeyboardInterrupt:
            if owned_worker and process_identity(owned_worker[0]) == owned_worker[1]:
                try:
                    os.kill(owned_worker[0], signal.SIGKILL)
                except ProcessLookupError:
                    pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
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


def report(args, summaries, host):
    result = {"schemaVersion": 1, "identity": host, "planned": 0 if args.crash_proof or args.replay_bundle else args.scenarios,
              "horizon": args.horizon, "fullAccess": args.full_access, "mode": args.mode, "policy": args.policy,
              "hero": args.hero, "companion": args.companion, "workers": summaries}
    result["completed"] = sum(s.get("termination") == "completedObjective" and s["exitCode"] == 0 for s in summaries)
    completed = [s for s in summaries if s.get("termination") == "completedObjective" and s["exitCode"] == 0]
    result["careersWithVictory"] = wilson(sum("victory" in s.get("outcomes", []) for s in completed), len(completed))
    result["incomplete"] = sum(s.get("termination") not in {"completedObjective", "replayedRecordedActions",
                               "replayedUnknownOutcome", "recoveredCapturedStore"} for s in summaries)
    if args.baseline:
        baseline = json.loads(args.baseline.read_text())
        if any(baseline.get(key) != result[key] for key in ("horizon", "fullAccess", "mode", "policy", "hero", "companion")):
            raise ValueError("baseline manifest does not match horizon/access")
        old = {s["seed"]: s for s in baseline["workers"]}
        if set(old) != {s["seed"] for s in summaries} or any(old[s["seed"]].get("scenarioManifest") != s.get("scenarioManifest") for s in summaries):
            raise ValueError("baseline must have identical scenario manifests and seed population")
        result["pairedComparison"] = [{"seed": s["seed"], "before": old[s["seed"]].get("outcomes", []),
                                       "after": s.get("outcomes", []),
                                       "goldEarnedDelta": s.get("goldEarned", 0) - old[s["seed"]].get("goldEarned", 0)}
                                      for s in summaries if s["seed"] in old]
        deltas = [pair["goldEarnedDelta"] for pair in result["pairedComparison"]]
        result["goldEarnedEffect"] = {"pairedCareers": len(deltas), "meanDelta": statistics.mean(deltas) if deltas else None,
                                     "standardError": statistics.stdev(deltas) / math.sqrt(len(deltas)) if len(deltas) > 1 else None}
    (args.output / "report.json").write_text(json.dumps(result, indent=2))
    rows = "".join(f"<tr><td>{html.escape(s['worker'])}</td><td>{s['seed']}</td><td>{html.escape(s['termination'])}</td>"
                   f"<td>{html.escape(', '.join(s.get('outcomes', [])))}</td><td>{s.get('talents', 0)} / {s.get('equipmentChanges', 0)} / {s.get('upgrades', 0)}</td><td>{s['processWallSeconds']:.2f}</td></tr>" for s in summaries)
    (args.output / "report.html").write_text("<!doctype html><meta charset='utf-8'><title>Trinket playthroughs</title>"
        "<style>body{font:16px system-ui;margin:3rem;max-width:1100px}td,th{text-align:left;padding:.6rem;border-bottom:1px solid #bbb}</style>"
        "<h1>Trinket playthroughs</h1><p>Manual diagnostic data. Bot outcomes are not player win-rate estimates.</p>"
        f"<p>Planned {result['planned']}; completed {result['completed']}; incomplete {result['incomplete']}.</p>"
        "<table><tr><th>Worker</th><th>Seed</th><th>Termination</th><th>Outcomes</th><th>Talents / equips / upgrades</th><th>Wall seconds</th></tr>" + rows + "</table>")
    return result


def interrupt_run(_signal, _frame):
    raise KeyboardInterrupt


def main():
    args = parse_args()
    signal.signal(signal.SIGTERM, interrupt_run)
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
    if args.crash_proof:
        success = all((args.output / name / "interrupted.json").exists() for name in ("interrupted", "settlement-interrupted")) and all(
            s["exitCode"] == 0 and s["termination"] in {"recoveredCapturedStore", "replayedUnknownOutcome"}
            for s in summaries if s["worker"] not in {"interrupted", "settlement-interrupted"})
    else:
        success = all(s["exitCode"] == 0 and s["termination"] in {"completedObjective", "replayedRecordedActions", "reproducedFailure"} for s in summaries)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
