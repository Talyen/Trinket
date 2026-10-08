#!/usr/bin/env python3
"""Stateless scoped status, safeguards, ownership guidance, and check selection."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shlex
import sys

from internal.agent_arguments import AgentArgumentParser
from internal.agent_status import briefing
from internal.agent_tasks import guidance_command, select_task
from internal.change_routing import BEHAVIOR_CARDS, classify, collect_paths, verification_plan
from internal.cli import ROOT


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser('agent-brief.py', description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument('--paths', nargs=argparse.REMAINDER)
    scope.add_argument('--working-tree', action='store_true')
    parser.add_argument('--task')
    for flag in ('agent', 'full', 'status', 'smoke', 'allow-broad-scope', 'read-command'):
        parser.add_argument('--' + flag, action='store_true')
    args = parser.parse_args(argv)
    try:
        task = select_task(root, args.task) if args.task else None
        if task and args.working_tree: parser.error('--task cannot combine with --working-tree; use --paths for the actual task scope')
        if args.paths == []: parser.error('--paths requires at least one repository-relative path')
        if args.paths is None and not args.working_tree and not task: parser.error('agent-brief requires --paths <file...>; use --working-tree to classify the whole tree intentionally')
        paths = collect_paths(args.paths if args.paths is not None else task['sources'] if task else None, root)
        limit = os.environ.get('TRINKET_MAX_WORKING_TREE_PATHS', '40')
        limit = int(limit) if limit.isdigit() else 40
        if args.working_tree and not args.allow_broad_scope and len(paths) > limit:
            parser.exit(3, f'working-tree scope has {len(paths)} paths; use explicit --paths or --allow-broad-scope\n')
        route = classify(paths, root)
        focus = task['contracts'] if task else []
        initial = [*route.guides, *(card for card in route.cards if card.partition('#')[0] not in BEHAVIOR_CARDS)]
        read = guidance_command(root, task, initial) if task else None
        if args.read_command:
            if not task or args.status: parser.error('--read-command requires --task and cannot combine with --status')
            print(read)
            return 0
        if args.status: print(briefing(root, paths))
        print(f'Agent context ({"working tree" if args.working_tree else "explicit paths"}, {len(paths)}):')
        def emit(label: str, values: list[str]) -> None:
            if values:
                print(label + ':')
                print('\n'.join('  ' + value for value in values))
        emit('Read first (reuse unchanged guidance already in context)', ['AGENTS.md', *route.guides])
        if task: emit(f'Concern focus: {task["label"]} (routed ownership/behavior; follow relevant callers/sections)', focus)
        cards = [card for card in route.cards if card not in focus]
        emit('Ownership and integration (read applicable constraints)', [card for card in cards if card.partition('#')[0] not in BEHAVIOR_CARDS])
        emit('Behavior references (read relevant sections and follow dependencies)', [card for card in cards if card.partition('#')[0] in BEHAVIOR_CARDS])
        triggers = {'apple-design': 'visual or interaction changes', 'architect': 'public type, protocol, schema, or package boundary changes', 'doc-budget': 'checker directives or suppression failures'}
        emit('Skills (load only when the trigger applies)', [skill + ' — ' + triggers.get(Path(skill).parent.name, 'see skill description') for skill in route.skills])
        emit('Memory (only for its concern)', route.knowledge)
        if read: emit('Suggested initial reads (root already injected; follow other relevant behavior and skill references)', [read])
        if task:
            emit('Source entry points (navigation only)', task['sources'])
            emit('Test pointers (inspect assertions; not coverage proof)', task['tests'])
        roots = sorted({('/'.join(path.split('/')[:2]) if path.startswith('Packages/') else 'Scripts' if path.startswith('Scripts/') else 'Trinket' if path.startswith(('Trinket/', 'TrinketUITests/')) else '') for path in paths} - {''})
        if roots:
            print('Discovery: filename regex (--glob for shell patterns); --related for source/test symbol hints; --excerpts for lines:')
            for owner in roots:
                print('  python3 Scripts/agent-search.py --files "<pattern>" --scope ' + shlex.quote(owner))
                print('  ' + (f'source/tests: {owner} (test mode includes support targets)' if owner.startswith('Packages/') else 'source: Scripts; tests: Scripts/Tests' if owner == 'Scripts' else 'source: Trinket; tests: TrinketUITests'))
        if args.full: emit(f'Authored paths ({len(route.authored)})', route.authored)
        emit(f'Generated/processed paths (do not hand-edit) ({len(route.generated)})', route.generated)
        emit('Boundary warnings', route.warnings)
        emit('Generated-output warnings', route.generated_warnings)
        handoff = ['./Scripts/handoff.sh', '--isolate', '--quiet', *(['--working-tree'] if args.working_tree else ['--paths', *paths])]
        emit('Verification (agents: always --isolate)', [shlex.join(handoff)])
        if args.full: emit('Plan detail (sequential under that tenant)', [check.command + (' (deferred to CI locally)' if check.deferred else '') for check in verification_plan(route, root=root, smoke=args.smoke)])
        if route.smoke_unresolved: print('UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke.')
        return 0
    except (OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    raise SystemExit(main())
