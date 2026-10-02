#!/usr/bin/env python3
"""Run read/context commands with a temporary receipt bound to this chat and repo."""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT
from internal.agent_arguments import AgentArgumentParser
from internal.agent_references import session_receipt
from internal.agent_tasks import select_task


def brief(arguments: list[str], chat: str, root: Path) -> int:
    parser = AgentArgumentParser('agent-session.py', description='Read a bounded initial task briefing.')
    parser.add_argument('--task', required=True)
    parser.add_argument('--limit', type=int, default=8, help='source signatures per file; continuations stay visible')
    parser.add_argument('--paths', nargs='+', help='actual task files; otherwise indexed source entry points')
    parser.add_argument('--reuse-guidance', action='store_true', help='reuse unchanged guidance still in context; forget after compaction')
    args = parser.parse_args(arguments)
    if args.limit < 1:
        parser.error('--limit must be positive')
    task = select_task(root, args.task)
    paths = args.paths or task['sources']
    route = ['--task', task['id'], '--paths', *paths]
    status = subprocess.run(['bash', 'Scripts/agent-context.sh', '--session', chat, '--status', *route], cwd=root).returncode
    if status:
        return status
    status = main(['--chat', chat, 'read', *route, *(['--reuse-guidance'] if args.reuse_guidance else [])], root=root)
    print('Source signatures (navigation only; inspect bodies and callers):', flush=True)
    for path in dict.fromkeys(paths):
        if Path(path).suffix not in {'.swift', '.py'}:
            print(f'  {path}: explicit text read required', flush=True)
            continue
        result = subprocess.run(['python3', 'Scripts/agent-read.py', path, '--signatures', '--limit', str(args.limit)], cwd=root)
        status = max(status, result.returncode)
    print('Test pointers (inspect assertions; not proof of coverage):')
    for path in task['tests']:
        print(f'  {path}')
    return status


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser("agent-session.py", description=__doc__)
    parser.add_argument("--chat", default=os.environ.get("CODEX_THREAD_ID"), help="defaults to CODEX_THREAD_ID; must identify this chat")
    parser.add_argument("command", choices=("read", "context", "brief", "forget"))
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if not args.chat or not args.chat.strip():
        parser.error("supply --chat CHAT_ID when CODEX_THREAD_ID is unavailable")
    if args.command == 'brief':
        try:
            return brief(args.arguments, args.chat, root)
        except (OSError, ValueError) as error:
            parser.error(str(error))
    if args.command == "forget":
        if args.arguments:
            parser.error("forget accepts no command arguments")
        session_receipt(args.chat, root).unlink(missing_ok=True)
        print("Cleared this chat's guidance receipt; reread applicable contracts after context loss.")
        return 0
    executable = ["python3", "Scripts/agent-read.py"] if args.command == "read" else ["bash", "Scripts/agent-context.sh"]
    if args.command == 'read' and any(arg == '--task' or arg.startswith('--task=') for arg in args.arguments):
        routing_arguments = []
        for argument in args.arguments:
            if argument == '--reuse-guidance':
                continue
            routing_arguments.extend(['--task', argument.removeprefix('--task=')] if argument.startswith('--task=') else [argument])
        route = subprocess.run(['bash', 'Scripts/agent-context.sh', '--session', args.chat,
                                '--read-command', *routing_arguments], cwd=root, capture_output=True, text=True)
        if route.returncode:
            print(route.stderr, end='', file=sys.stderr)
            return route.returncode
        command = shlex.split(route.stdout.strip())
        if '--reuse-guidance' in args.arguments:
            command.append('--reuse-guidance')
        return subprocess.run(command, cwd=root).returncode
    return subprocess.run([*executable, "--session", args.chat, *args.arguments], cwd=root).returncode


if __name__ == "__main__":
    raise SystemExit(main())
