"""Small authored concern index: navigation hints, never policy or coverage proof."""

from __future__ import annotations

import json
import re
import shlex
from pathlib import Path

from internal.agent_references import fingerprint


def within(name: str, scopes: list[str]) -> bool:
    return not scopes or any(name == scope or name.startswith(scope + "/") for scope in scopes)


def load_tasks(root: Path) -> list[dict]:
    path = root / "Scripts/config/agent-tasks.json"
    if not path.exists():
        return []
    tasks = json.loads(path.read_text())
    if not isinstance(tasks, list):
        raise ValueError("agent task index must contain a list")
    ids = set()
    checked_references = set()
    for task in tasks:
        if not isinstance(task, dict) or not isinstance(task.get("id"), str) or not task["id"] or task["id"] in ids:
            raise ValueError("agent task IDs must be nonempty and unique")
        ids.add(task["id"])
        if not isinstance(task.get("label"), str) or not task["label"].strip():
            raise ValueError(f"{task['id']}: missing label")
        for field in ("aliases", "symbols", "sources", "tests", "contracts"):
            values = task.get(field)
            if not isinstance(values, list) or not values or any(not isinstance(value, str) or not value.strip() for value in values):
                raise ValueError(f"{task['id']}: {field} must contain nonempty strings")
            if len(values) != len(set(values)):
                raise ValueError(f"{task['id']}: duplicate {field}")
        for reference in (*task["sources"], *task["tests"], *task["contracts"]):
            if reference in checked_references:
                continue
            name = reference.partition("#")[0]
            if Path(name).is_absolute() or ".." in Path(name).parts:
                raise ValueError(f"{task['id']}: index paths must be repository-relative")
            fingerprint(root, reference)
            checked_references.add(reference)
    return tasks


def find_tasks(root: Path, query: str, scopes: list[str]) -> list[str]:
    rows = []
    for task in matching_tasks(root, query, scopes):
        lines = [f"{task['label']} ({task['id']}):"]
        for label, field in (("Source", "sources"), ("Test pointer", "tests"), ("Contract", "contracts")):
            lines.extend(f"  {label}: {name}" for name in task[field])
        lines.append("  Route: " + shlex.join(["./Scripts/agent-context.sh", "--agent", "--status", "--task", task["id"]]))
        rows.append("\n".join(lines))
    return rows


def matching_tasks(root: Path, query: str, scopes: list[str]) -> list[dict]:
    words = set(re.findall(r"\w+", query.casefold()))
    if not words:
        raise ValueError("--task requires a concern name, such as 'Shop purchase'")
    matches = []
    for task in load_tasks(root):
        names = [task["id"], task["label"], *task["aliases"]]
        if not any(words <= set(re.findall(r"\w+", name.casefold())) for name in names):
            continue
        if not any(within(name, scopes) for name in task["sources"]):
            continue
        matches.append(task)
    return matches


def select_task(root: Path, query: str) -> dict:
    matches = matching_tasks(root, query, [])
    if len(matches) != 1:
        choices = ", ".join(task["id"] for task in matches) or "none"
        raise ValueError(f"--task requires one indexed concern; matches: {choices}. List concerns: python3 Scripts/agent-search.py --task --overview")
    return matches[0]


def related_tests(root: Path, symbol: str, source_files: set[str], test_files: set[str], ignore_case: bool) -> set[str]:
    selected = set()
    for task in load_tasks(root):
        matches = any(name.casefold() == symbol.casefold() if ignore_case else name == symbol for name in task["symbols"])
        if matches and source_files.intersection(task["sources"]):
            selected.update(test_files.intersection(task["tests"]))
    return selected


def guidance_command(root: Path, task: dict, guides: list[str], chat: str | None = None,
                     receipt: str | None = None) -> str:
    """Initial applicable guidance; behavior discovery and skill triggers stay visible."""
    references = list(dict.fromkeys([*guides, *task['contracts']]))
    command = ['python3', 'Scripts/agent-read.py'] if receipt else ['python3', 'Scripts/agent-session.py']
    if receipt:
        command += ['--receipt', receipt, '--chat', chat]
    else:
        if chat:
            command += ['--chat', chat]
        command.append('read')
    for reference in references:
        name, separator, _ = reference.partition('#')
        fingerprint(root, reference)
        flags = ['--full'] if not separator else []
        command += ['--request', shlex.join([reference, *flags])]
    return shlex.join(command)


if __name__ == "__main__":
    import argparse
    from internal.cli import ROOT

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query")
    parser.add_argument("--field", choices=("sources", "contracts", "label", "read-command"), required=True)
    parser.add_argument("--guide", action="append", default=[])
    parser.add_argument("--chat")
    parser.add_argument("--receipt")
    args = parser.parse_args()
    try:
        task = select_task(ROOT, args.query)
        if args.field == 'read-command':
            if args.receipt and not args.chat:
                raise ValueError('--receipt requires --chat')
            print(guidance_command(ROOT, task, args.guide, args.chat, args.receipt))
        else:
            print("\n".join(task[args.field]) if args.field != "label" else task["label"])
    except (OSError, ValueError) as error:
        parser.exit(2, f"Task routing failed: {error}\n")
