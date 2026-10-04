#!/usr/bin/env python3
"""Measure retrieval probes or compare controlled, externally measured complete tasks."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT
from internal.agent_tasks import select_task
from internal.agent_references import session_receipt

SCENARIOS = (
    ("combat", "Investigate shared Mana empowerment quotes, payment limits, and regressions.",
     "Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift", "ManaEmpowermentBudget",
     ["Packages/BattleEngine"]),
    ("shop", "Investigate Shop purchase eligibility and its regression coverage.",
     "Trinket/Features/Play/Shop/ShopEncounterView.swift", "ShopPurchaseApplier",
     ["Packages/TrinketPersistence", "Trinket/Features"]),
    ("persistence", "Investigate roster talent changes, sanitization, and durable save acceptance.",
     "Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Roster.swift", "unlockTalent",
     ["Packages/TrinketPersistence", "Packages/TrinketAppState"]),
    ("tooling", "Investigate documentation links and checker regression ownership.",
     "Scripts/check-links.py", "broken_links", ["Scripts"]),
)
TASK_METRICS = ("total_tokens", "repeated_reads", "retries", "failed_commands", "unnecessary_stops")
EXTENDED_SCENARIOS = (
    ('particles', 'Investigate slice particle geometry and fidelity regression evidence.',
     'Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Effects/CombatantSliceParticles.swift',
     'SliceCutParticle', ['Packages/TrinketBattleFeature']),
    ('feedback', 'Investigate floating combat feedback ownership, lifetime and regression evidence.',
     'Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/State/Feedback/CombatFeedbackPresenter.swift',
     'CombatFeedbackPresenter', ['Packages/TrinketBattleFeature']),
    ('collection', 'Investigate Collection mounting, artwork retention and relevant UI assertions.',
     'Trinket/Features/Collection/CollectionView.swift', 'CollectionView', ['Trinket/Features/Collection', 'TrinketUITests']),
    ('simulator', 'Investigate simulator isolation and guest process safety using script assertions only.',
      'Scripts/run-env.sh', 'trinket_run_env_init', ['Scripts']),
    ('voyage', 'Investigate Voyage completion, encounter identities and saved reward claims.',
     'Packages/TrinketPersistence/Sources/TrinketPersistence/Progression/VoyageCompletion.swift',
     'VoyageCompletion', ['Packages/TrinketPersistence', 'Packages/TrinketAppState']),
    ('labyrinth', 'Investigate Labyrinth completion, recovery and durable progress.',
     'Packages/TrinketPersistence/Sources/TrinketPersistence/Progression/LabyrinthCompletion.swift',
     'LabyrinthCompletion', ['Packages/TrinketPersistence', 'Packages/TrinketAppState']),
)


def prepare_tasks(root: Path, repetitions: int = 1, suite: str = 'core') -> dict:
    """Keep unmeasured fields null; collection requires evidence from real trials."""
    if repetitions < 1:
        raise ValueError("repetitions must be positive")
    return {"kind": "task", "context": {"source_sha256": source_fingerprint(root),
            "model": None, "reasoning": None, "tools": None},
            "tasks": [{"id": name if repetitions == 1 else f"{name}-{run + 1}", "request": request,
                       "acceptance": ["Identify the owning source and relevant callers.",
                                      "Inspect test assertions and explain relevant game/save constraints.",
                                      "Distinguish verified evidence, inference and remaining verification."],
                       "correct": None, "complete": None,
                       "evidence": None, "usage_file": None, "usage_evidence": None,
                       "metrics": {metric: None for metric in TASK_METRICS}}
                      for run in range(repetitions)
                      for name, request, *_ in (SCENARIOS + EXTENDED_SCENARIOS if suite == 'extended' else SCENARIOS)]}


def collect_tasks(manifest: Path) -> dict:
    """Import per-response provider usage, never cumulative samples or estimates."""
    report = json.loads(manifest.read_text())
    if report.get("kind") != "task":
        raise ValueError("collect requires a complete-task manifest")
    seen_responses = set()
    for task in report.get("tasks", []):
        if any(type(task.get(field)) is not bool for field in ("correct", "complete")):
            raise ValueError(f"{task.get('id')}: correctness and completion require independent boolean judgements")
        if not task.get("usage_file") or not task.get("usage_evidence"):
            raise ValueError(f"{task.get('id')}: supply a provider usage export and its extraction evidence")
        usage_path = manifest.parent / task["usage_file"]
        data = usage_path.read_bytes()
        usage = json.loads(data)
        if not isinstance(usage, list) or not usage:
            raise ValueError("usage exports must contain final per-response input/output counts")
        total = 0
        for response in usage:
            if not isinstance(response, dict) or not isinstance(response.get("id"), str) or not response["id"]:
                raise ValueError("each usage response requires its provider response ID")
            if response["id"] in seen_responses:
                raise ValueError("duplicate usage response ID; do not double-count responses or cumulative samples")
            seen_responses.add(response["id"])
            for field in ("input_tokens", "output_tokens"):
                value = response.get(field)
                if type(value) is not int or value < 0:
                    raise ValueError(f"usage {field} must be an actual nonnegative integer")
                total += value
        supplied = task["metrics"].get("total_tokens")
        if supplied is not None and supplied != total:
            raise ValueError(f"{task['id']}: supplied total_tokens disagrees with provider usage")
        task["metrics"]["total_tokens"] = total
        task["usage_sha256"] = hashlib.sha256(data).hexdigest()
        task["response_count"] = len(usage)
    # Validate measurement and independent judgement fields with the existing
    # comparator. Incorrect/incomplete outcomes remain recordable, never accepted.
    compare(report, report)
    return report


def source_fingerprint(root: Path) -> str:
    """Product inputs, excluding the guidance/retrieval tooling being compared."""
    names = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root,
    ).decode().split("\0")
    digest = hashlib.sha256()
    for name in sorted(set(names) - {""}):
        path = root / name
        product = name.startswith(("Packages/", "Trinket/", "TrinketUITests/")) and path.suffix in {".swift", ".json", ".yml"}
        product |= (name.split("/")[0].endswith("Manifest") and path.suffix == ".tsv")
        product |= name in {"project.yml", "Scripts/tool-versions.env", "Scripts/check-links.py"}
        if product and path.is_file():
            digest.update(name.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def probe(root: Path, workflow: str = "paths", suite: str = 'core') -> dict:
    root = root.resolve()
    initial_source = source_fingerprint(root)
    concern_ids = {"combat": "mana", "shop": "shop", "persistence": "talents", "tooling": "tooling"}
    tasks = []
    for name, request, owner, symbol, scopes in (SCENARIOS + EXTENDED_SCENARIOS if suite == 'extended' else SCENARIOS):
        trace = []

        def run(arguments: list[str], *, read_targets: list[str] | None = None) -> str:
            result = subprocess.run(arguments, cwd=root, capture_output=True, text=True, timeout=60)
            trace.append({"command": arguments, "exit_code": result.returncode,
                          "output_characters": len(result.stdout) + len(result.stderr),
                          "read_targets": read_targets or []})
            if result.returncode:
                raise ValueError(f"{name}: command failed ({result.returncode}): {' '.join(arguments)}\n{result.stderr}")
            return result.stdout

        if workflow == 'briefings':
            task = select_task(root, concern_ids.get(name, name))
            chat = f'efficiency-brief-{name}'
            receipt = session_receipt(chat, root)
            receipt.unlink(missing_ok=True)
            try:
                arguments = [sys.executable, 'Scripts/agent-session.py', '--chat', chat, 'brief', '--task', task['id']]
                briefing = run(arguments)
                run([*arguments, "--reuse-guidance"])
            finally:
                receipt.unlink(missing_ok=True)
            tasks.append({'id': name, 'request': request,
                          'metrics': {'output_characters': sum(step['output_characters'] for step in trace),
                                      'commands': len(trace), 'failed_commands': 0},
                          'handoff': next(line.strip() for line in briefing.splitlines() if './Scripts/handoff.sh' in line),
                          'trace': trace})
            continue
        if workflow == "concerns":
            task = select_task(root, concern_ids.get(name, name))
            arguments = ["--task", task["id"]]
        else:
            arguments = ["--paths", owner]
        briefing = run(["bash", "Scripts/agent-context.sh", "--agent", *arguments])
        references = []
        in_guidance = False
        focused = workflow == "concerns"
        for line in briefing.splitlines():
            if not line.startswith("  "):
                headers = ("Read first", "Ownership and integration", "Concern focus") if focused else (
                    "Read first", "Ownership and integration", "Behavior references")
                in_guidance = line.startswith(headers)
            elif in_guidance and line.strip() != "AGENTS.md":
                references.append(line.strip())
        references = list(dict.fromkeys(references))
        # Root guidance is already injected. Skills/knowledge stay trigger-based;
        # these probes do not implement visual, API, or schema changes.
        end = min(80, len((root / owner).read_text().splitlines()))
        if workflow == "concerns":
            arguments = []
            for ref in references:
                flags = ["--full"] if "#" not in ref and len((root / ref).read_text()) > 12_000 else []
                arguments += ["--request", shlex.join([ref, *flags])]
            arguments += ["--request", shlex.join([owner, "--lines", f"1:{end}"])]
            run([sys.executable, "Scripts/agent-read.py", *arguments], read_targets=[*references, owner])
        else:
            small = [ref for ref in references if "#" in ref or len((root / ref).read_text()) <= 12_000]
            large = [ref for ref in references if ref not in small]
            if small:
                run([sys.executable, "Scripts/agent-read.py", *small], read_targets=small)
            if large:
                run([sys.executable, "Scripts/agent-read.py", *large, "--full"], read_targets=large)
            run([sys.executable, "Scripts/agent-read.py", owner, "--lines", f"1:{end}"], read_targets=[owner])
        scope_args = [argument for scope in scopes for argument in ("--scope", scope)]
        run([sys.executable, "Scripts/agent-search.py", symbol, "--related", *scope_args])
        tasks.append({"id": name, "request": request,
                      "metrics": {"output_characters": sum(step["output_characters"] for step in trace),
                                  "commands": len(trace), "failed_commands": 0},
                      "references": references,
                      "handoff": next(line.strip() for line in briefing.splitlines() if "./Scripts/handoff.sh" in line),
                      "trace": trace})
    if source_fingerprint(root) != initial_source:
        raise ValueError("product inputs changed during the probes; use an immutable snapshot")
    return {"kind": "retrieval", "context": {"source_sha256": initial_source,
              "probe_version": 3 if workflow == 'briefings' else 2 if workflow == "concerns" else 1,
              "workflow": workflow, "suite": suite}, "tasks": tasks}


def compare(before: dict, after: dict) -> tuple[list[str], bool]:
    kind = before.get("kind")
    if kind not in {"retrieval", "task"} or after.get("kind") != kind:
        raise ValueError("compare reports of the same kind: retrieval or task")
    required_context = ("source_sha256", "probe_version") if kind == "retrieval" else ("source_sha256", "model", "reasoning", "tools")
    for key in required_context:
        value = before.get("context", {}).get(key)
        if value is None or after.get("context", {}).get(key) != value:
            raise ValueError(f"comparison requires identical context.{key}")
    if not re.fullmatch(r"[0-9a-f]{64}", str(before['context']['source_sha256'])):
        raise ValueError("context.source_sha256 must identify the actual starting inputs")
    groups = []
    for report in (before, after):
        tasks = report.get("tasks", [])
        group = {task["id"]: task for task in tasks}
        if not group or any(not isinstance(name, str) or not name for name in group) or len(group) != len(tasks):
            raise ValueError("task IDs must be nonempty and unique")
        groups.append(group)
    if groups[0].keys() != groups[1].keys():
        raise ValueError("comparison requires identical task IDs")
    rows = []
    accepted = True
    metrics = ("output_characters", "commands", "failed_commands") if kind == "retrieval" else TASK_METRICS
    for name, old in groups[0].items():
        new = groups[1][name]
        if not old.get("request") or old["request"] != new.get("request"):
            raise ValueError(f"{name}: requests differ")
        if kind == "retrieval":
            if old.get("handoff") != new.get("handoff"):
                raise ValueError(f"{name}: verification routing changed")
        else:
            for task in (old, new):
                if not task.get("evidence"):
                    raise ValueError(f"{name}: complete-task reports require correctness/completion evidence")
                if task.get("correct") is not True or task.get("complete") is not True:
                    accepted = False
        for metric in metrics:
            values = [task.get("metrics", {}).get(metric) for task in (old, new)]
            if any(type(value) is not int or value < 0 for value in values):
                raise ValueError(f"{name}: {metric} must be a measured nonnegative integer")
            left, right = values
            change = 100 * (left - right) / left if left else 0
            reduction = (f"{abs(change):.1f}% {'reduction' if change >= 0 else 'increase'}"
                         if left else "no baseline percentage")
            rows.append(f"{name}: {metric} {left} -> {right} ({reduction})")
    label = "Retrieval probes: characters/commands only; total task tokens are unmeasured." if kind == "retrieval" else (
        "Complete-task comparison accepted." if accepted else "Complete-task comparison FAILED correctness/completion; token savings are not an acceptance.")
    return [label, *rows], accepted


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    probes = commands.add_parser("probe", help="read-only combat, Shop, persistence, and tooling retrieval workflows")
    probes.add_argument("--root", type=Path, default=ROOT)
    probes.add_argument("--output", type=Path, required=True)
    probes.add_argument("--workflow", choices=("paths", "concerns", "briefings"), default="paths", help="briefings compares cold and repeated task briefs; never task-token usage")
    probes.add_argument('--suite', choices=('core', 'extended'), default='core')
    comparison = commands.add_parser("compare", help="reject mismatched sources/settings and prioritize correctness over tokens")
    comparison.add_argument("baseline", type=Path)
    comparison.add_argument("candidate", type=Path)
    preparation = commands.add_parser("prepare", help="create an unmeasured complete-task manifest for the four scenarios")
    preparation.add_argument("--root", type=Path, default=ROOT)
    preparation.add_argument("--output", type=Path, required=True)
    preparation.add_argument("--repetitions", type=int, default=1, help="prepare repeated trials with distinct IDs; keep every outcome")
    preparation.add_argument('--suite', choices=('core', 'extended'), default='core')
    collection = commands.add_parser("collect", help="validate trial evidence and sum exported final per-response usage")
    collection.add_argument("manifest", type=Path)
    collection.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command in {"prepare", "collect"}:
            report = prepare_tasks(args.root, args.repetitions, args.suite) if args.command == "prepare" else collect_tasks(args.manifest)
            args.output.write_text(json.dumps(report, indent=2) + "\n")
            print(f"{'Unmeasured trial manifest' if args.command == 'prepare' else 'Measured task report'}: {args.output}")
            return 0
        if args.command == "probe":
            report = probe(args.root, args.workflow, args.suite)
            args.output.write_text(json.dumps(report, indent=2) + "\n")
            print(f"Retrieval report: {args.output}")
            for task in report["tasks"]:
                print(f"{task['id']}: {task['metrics']['output_characters']} characters, {task['metrics']['commands']} commands")
            return 0
        rows, accepted = compare(json.loads(args.baseline.read_text()), json.loads(args.candidate.read_text()))
        print("\n".join(rows))
        return 0 if accepted else 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        parser.exit(2, f"Efficiency comparison failed: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
