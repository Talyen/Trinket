#!/usr/bin/env python3
"""Stateless scoped status, safeguards, ownership guidance, and check selection."""
from __future__ import annotations

import os
from pathlib import Path
import shlex
import subprocess

from internal.agent_arguments import AgentArgumentParser
from internal.agent_status import briefing
from internal.agent_tasks import guidance_command, select_task
from internal.change_routing import BEHAVIOR_CARDS, classify, collect_paths, verification_plan
from internal.cli import ROOT, load_sibling


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser('agent-brief.py', description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument('--paths', nargs='+')
    scope.add_argument('--working-tree', action='store_true')
    scope.add_argument('--base', help='include task commits since the shared ancestor of REF and HEAD, plus dirty files')
    parser.add_argument('--task')
    for flag in ('agent', 'full', 'status', 'smoke', 'allow-broad-scope', 'read-command'):
        parser.add_argument('--' + flag, action='store_true')
    parser.add_argument('--read', action='store_true', help='read safeguards and concise ownership; add --full to expand behavior contracts')
    args = parser.parse_args(argv)
    try:
        task = select_task(root, args.task) if args.task else None
        if task and args.working_tree: parser.error('--task cannot combine with --working-tree; use --paths for the actual task scope')
        if args.paths == []: parser.error('--paths requires at least one repository-relative path')
        if args.paths is None and not args.working_tree and not args.base and not task: parser.error('agent-brief requires --paths <file...>, --base <ref>, or --task <concern>')
        paths = collect_paths(args.paths if args.paths is not None else task['sources'] if task and not args.base else None, root, base=args.base)
        limit = os.environ.get('TRINKET_MAX_WORKING_TREE_PATHS', '40')
        limit = int(limit) if limit.isdigit() else 40
        if args.working_tree and not args.allow_broad_scope and len(paths) > limit:
            parser.exit(3, f'working-tree scope has {len(paths)} paths; use explicit --paths or --allow-broad-scope\n')
        route = classify(paths, root, base=args.base)
        focus = task['contracts'] if task else []
        # Initial reads cover ownership; behavior depth is an explicit expansion.
        initial = [*route.guides, *(card for card in route.cards if args.full or card.partition('#')[0] not in BEHAVIOR_CARDS)]
        read = guidance_command(root, task, initial, full=args.full) if task or initial else None
        if args.read_command:
            if args.status or args.read: parser.error('--read-command cannot combine with --status or --read')
            if read: print(read)
            return 0
        if args.status: print(briefing(root, paths))
        print(f'Agent context ({"base " + args.base if args.base else "working tree" if args.working_tree else "explicit paths"}, {len(paths)}):')
        def emit(label: str, values: list[str]) -> None:
            if values:
                print(label + ':')
                print('\n'.join('  ' + value for value in values))
        emit('Read first (reuse unchanged guidance already in context)', ['AGENTS.md', *route.guides])
        if task: emit(f'Concern focus: {task["label"]} (routed ownership/behavior; follow relevant callers/sections)', focus)
        cards = [card for card in route.cards if card not in focus]
        emit('Ownership and integration (read applicable constraints)', [card for card in cards if card.partition('#')[0] not in BEHAVIOR_CARDS])
        emit('Behavior references (read relevant sections and follow dependencies)', [card for card in cards if card.partition('#')[0] in BEHAVIOR_CARDS])
        triggers = {'apple-design': 'visual or interaction changes', 'architect': 'public type, protocol, schema, or package boundary changes', 'doc-budget': 'checker directives or suppression failures', 'swiftui-specialist': 'SwiftUI state, identity, correctness or update performance'}
        emit('Skills (load only when the trigger applies)', [skill + ' — ' + triggers.get(Path(skill).parent.name, 'see skill description') for skill in route.skills])
        emit('Memory (only for its concern)', route.knowledge)
        if read and task and not args.read: emit('Suggested initial reads (root already injected; follow other relevant behavior and skill references)', [read])
        if task:
            emit('Source entry points (navigation only)', task['sources'])
            emit('Test pointers (inspect assertions; not coverage proof)', task['tests'])
        roots = sorted({('/'.join(path.split('/')[:2]) if path.startswith('Packages/') else 'Scripts' if path.startswith('Scripts/') else 'Trinket' if path.startswith(('Trinket/', 'TrinketUITests/')) else '') for path in paths} - {''})
        if 'Trinket' in roots:
            roots.append('TrinketUITests')
        if roots:
            emit('Source owners (use scoped rg, file reads and git diff)', roots)
        if args.full: emit(f'Authored paths ({len(route.authored)})', route.authored)
        emit(f'Generated/processed paths (do not hand-edit) ({len(route.generated)})', route.generated)
        emit('Boundary warnings', route.warnings)
        emit('Generated-output warnings', route.generated_warnings)
        handoff = ['./Scripts/handoff.sh', '--isolate', '--quiet', *(['--base', args.base] if args.base else ['--working-tree'] if args.working_tree else ['--paths', *paths])]
        emit('Verify (selects scoped checks automatically; --dry-run previews)', [shlex.join(handoff)])
        emit('Landing (from the task worktree after review/commit; includes final static handoff)',
             ['node Scripts/agent-worktree.mjs integrate'])
        emit('Finish (after reporting and any remaining work)', ['node Scripts/agent-worktree.mjs cleanup'])
        if args.full: emit('Plan detail (sequential under that tenant)', [check.command + (' (deferred to CI locally)' if check.deferred else '') for check in verification_plan(route, root=root, smoke=args.smoke)])
        if route.smoke_unresolved: print('UI note: no single smoke owner was inferred. Apply the Testing rubric; add coverage only for a qualifying unique shipping outcome. Do not substitute bare smoke.')
        if args.read and read:
            print('Initial guidance (complete reads; follow behavior links for the change):')
            return load_sibling('brief_reader', 'agent-read.py').main(shlex.split(read)[2:], root=root)
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    raise SystemExit(main())
