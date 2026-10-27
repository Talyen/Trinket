#!/usr/bin/env python3
"""Stateless scoped status, safeguards, ownership guidance, and check selection."""
from __future__ import annotations

import os
import re
from pathlib import Path
import shlex
import subprocess

from internal.agent_arguments import AgentArgumentParser
from internal.agent_status import briefing
from internal.agent_tasks import guidance_command, select_task
from internal.change_routing import BEHAVIOR_CARDS, classify, collect_paths, verification_plan
from internal.cli import ROOT, load_sibling, read_env_arrays


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser('agent-brief.py', description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument('--paths', nargs='+')
    scope.add_argument('--working-tree', action='store_true')
    scope.add_argument('--base', help='include task commits since the shared ancestor of REF and HEAD, plus dirty files')
    parser.add_argument('--task')
    parser.add_argument('--owner', help='override CODEX_THREAD_ID for a local command preview')
    local = parser.add_mutually_exclusive_group()
    local.add_argument('--diagnostic-package', help='package for one exact local diagnostic suite')
    local.add_argument('--visual-command', action='store_true', help='show the managed visual inspection command')
    parser.add_argument('--diagnostic-suite', help='exact suite or target/suite for --diagnostic-package')
    for flag in ('agent', 'full', 'status', 'smoke', 'allow-broad-scope', 'read-command'):
        parser.add_argument('--' + flag, action='store_true')
    parser.add_argument('--read', action='store_true', help='read safeguards and concise ownership; add --full to expand behavior contracts')
    args = parser.parse_args(argv)
    try:
        if args.read_command and (args.diagnostic_package or args.visual_command or args.owner):
            parser.error('--read-command cannot combine with local command previews')
        if args.diagnostic_suite and not args.diagnostic_package:
            parser.error('--diagnostic-suite requires --diagnostic-package')
        if args.diagnostic_package and not args.diagnostic_suite:
            parser.error('--diagnostic-package requires one exact --diagnostic-suite')
        if args.owner and not (args.diagnostic_package or args.visual_command):
            parser.error('--owner requires --diagnostic-package or --visual-command')
        if args.diagnostic_package:
            known = read_env_arrays(root / 'Scripts/build-inputs.env', ['TRINKET_TEST_PACKAGES'])['TRINKET_TEST_PACKAGES']
            if args.diagnostic_package not in known:
                parser.error('--diagnostic-package requires a registered package')
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)?', args.diagnostic_suite):
                parser.error('--diagnostic-suite requires one suite or target/suite')
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
        emit('Applicable requirements (reuse unchanged guidance already in context)', ['AGENTS.md', *route.guides])
        if task: emit(f'Concern focus: {task["label"]} (routed ownership/behavior; follow relevant callers/sections)', focus)
        cards = [card for card in route.cards if card not in focus]
        emit('Applicable ownership requirements', [card for card in cards if card.partition('#')[0] not in BEHAVIOR_CARDS])
        emit('Optional reference depth (read when changing this behavior)', [card for card in cards if card.partition('#')[0] in BEHAVIOR_CARDS])
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
        handoff = ['./Scripts/handoff.sh', '--quiet', *(['--base', args.base] if args.base else ['--working-tree'] if args.working_tree else ['--paths', *paths])]
        emit('Iteration check (only the supplied scope)', [shlex.join(handoff)])
        if args.diagnostic_package or args.visual_command:
            owner = args.owner or os.environ.get('CODEX_THREAD_ID')
            if not owner:
                emit('Local command needs an owner', ['Supply --owner <thread-id>; no local command has been printed or run.'])
            else:
                helper = os.environ.get('CODEX_HEAVY_LANE_HELPER') or str(Path.home() / 'Developer/.coordination/heavy_lane.py')
                lane = ['python3', helper,
                        '--owner', owner, '--wait', '900', '--timeout', '30' if args.diagnostic_package else '300', '--']
                if args.diagnostic_package:
                    command = [*lane, 'env', 'TRINKET_ALLOW_HEAVY_LOCAL=1', 'TRINKET_ISOLATE=1',
                               'TRINKET_PACKAGE_TEST_JOBS=1', 'TRINKET_SERIAL_TESTS=1',
                               './Scripts/test-package.sh', '--only-suite', args.diagnostic_suite, args.diagnostic_package]
                    label = 'Focused diagnostic (one concrete unresolved question; 30 seconds per attempt, retry timeout)'
                else:
                    command = [*lane, './Scripts/handoff.sh', '--route', 'visual',
                               *(['--base', args.base] if args.base else ['--working-tree'] if args.working_tree else ['--paths', *paths])]
                    label = 'Visual inspection (when the visual gate applies; use a persistent terminal and review the result)'
                emit(label, [shlex.join(command), 'Admission wait is up to 900 seconds; preview is not verification evidence.',
                             'Run final static handoff separately; hosted qualification remains pending.'])
        emit('Final task verification (all task changes; --dry-run previews)',
             [shlex.join(['./Scripts/handoff.sh', '--quiet', *(['--base', args.base] if args.base else [])])])
        emit('Landing (from the task worktree after review/commit; includes final static handoff)',
             ['node Scripts/agent-worktree.mjs integrate'])
        plans = [root / path for path in paths if Path(path).parent == Path('Docs/Plans')
                 and Path(path).name != 'README.md' and (root / path).is_file()]
        if plans:
            check_plans = load_sibling('brief_check_plans', 'check-plans.py')
            if any(check_plans.plan_metadata(plan)[0].get('status') == 'active' for plan in plans):
                emit('Active plan in scope', ['Close it when finished, or retain intentional unfinished work with node Scripts/agent-worktree.mjs integrate --keep-plan'])
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
