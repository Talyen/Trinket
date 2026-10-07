#!/usr/bin/env python3
"""Read a declaration, enclosing context and scoped caller/test bodies in one bounded bundle."""

from __future__ import annotations

import hashlib
import re
import shlex
import subprocess
from pathlib import Path

from internal.cli import ROOT, load_sibling
from internal.agent_arguments import AgentArgumentParser
from internal.agent_callers import invocation_lines
from internal.agent_tasks import load_tasks
from internal.source_declarations import source_declarations, swift_code_tokens


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = AgentArgumentParser('agent-investigate.py', description=__doc__)
    parser.add_argument('--path', required=True, help='authored Swift/Python source file')
    parser.add_argument('--symbol', required=True, help='one declaration, qualified when ambiguous')
    parser.add_argument('--scope', action='append', required=True, help='exact source/test owner; repeat for cross-owner calls')
    parser.add_argument('--test', action='append', default=[], help='explicit test file#qualified-declaration, including assertions')
    parser.add_argument('--limit', type=int, default=6, help='caller/test bodies per page')
    parser.add_argument('--max-lines', type=int, default=160, help='body line budget; oversized bodies get explicit read commands')
    parser.add_argument('--offset', type=int, default=0)
    parser.add_argument('--expect', help='reject continuation after any scoped source/test edit')
    args = parser.parse_args(argv)
    try:
        if args.limit < 1 or args.max_lines < 1 or args.offset < 0:
            raise ValueError('limit/max-lines must be positive and offset nonnegative')
        for name in (args.path, *args.scope, *(ref.partition('#')[0] for ref in args.test)):
            path = root / name
            if Path(name).is_absolute() or '..' in Path(name).parts or path.is_symlink():
                raise ValueError(f'use exact repository paths without symlinks: {name}')
            path.resolve().relative_to(root.resolve())
            if not path.exists():
                raise ValueError(f'missing path/scope: {name}')
        search = load_sibling('investigation_search', 'agent-search.py')
        groups = search.inventory(root, ('source', 'tests'), args.scope)
        sources, tests = groups['source'], groups['tests']
        all_tests = search.inventory(root, ('tests',), [])['tests'] if args.test else tests
        if args.path not in sources or Path(args.path).suffix not in {'.py', '.swift'}:
            raise ValueError('--path must be an authored Swift/Python source within --scope')
        explicit = []
        for reference in args.test:
            name, separator, symbol = reference.partition('#')
            if not separator or not symbol or name not in all_tests or Path(name).suffix not in {'.py', '.swift'}:
                raise ValueError('--test requires an authored test file#qualified-declaration')
            explicit.append((name, symbol))
        files = sorted(set(sources + tests + [name for name, _ in explicit]))
        files = [name for name in files if Path(name).suffix in {'.py', '.swift'}]
        data = {name: (root / name).read_bytes() for name in files}
        contents = {name: raw.decode('utf-8') for name, raw in data.items()}
        lines = {name: source.splitlines() for name, source in contents.items()}
        digest = hashlib.sha256()
        for name, raw in data.items():
            digest.update(name.encode() + b'\0' + raw + b'\0')
        identity = digest.hexdigest()
        if args.expect and args.expect != identity:
            raise ValueError('scoped inputs changed; restart without --offset/--expect')
        declarations = {}
        token_streams = {}

        def tokens(name):
            if Path(name).suffix != '.swift':
                return None
            if name not in token_streams:
                token_streams[name] = swift_code_tokens(contents[name])
            return token_streams[name]

        def entries(name):
            if name not in declarations:
                declarations[name] = source_declarations(root / name, contents[name], tokens=tokens(name))
            return declarations[name]

        def select(name, symbol):
            found = [entry for entry in entries(name) if entry.name == symbol or entry.name.rsplit('.', 1)[-1] == symbol]
            if len(found) != 1:
                choices = ', '.join(f'{e.name} [{e.start}:{e.end}]' for e in found) or 'none'
                raise ValueError(f'{name}: declaration {symbol!r} must be unambiguous; candidates: {choices}')
            return found[0]

        target = select(args.path, args.symbol)
        leaf = target.name.rsplit('.', 1)[-1]
        units = []
        seen = {(args.path, target.start, target.end)}
        # Cheap textual filtering precedes lexical parsing. Invocation matching then
        # excludes strings/comments; the remaining hints still have no type resolution.
        for name in files:
            if not re.search(r'\b' + re.escape(leaf) + r'\b', contents[name]):
                continue
            for line in invocation_lines(root / name, contents[name], leaf, tokens=tokens(name)):
                enclosing = [entry for entry in entries(name) if entry.start <= line <= entry.end]
                entry = min(enclosing, key=lambda e: (e.end - e.start, -e.start)) if enclosing else None
                start, end = (entry.start, entry.end) if entry else (line, line)
                key = (name, start, end)
                if key not in seen:
                    seen.add(key)
                    units.append((name, entry, start, end, 'Test invocation' if name in all_tests else 'Caller'))
        for name, symbol in explicit:
            entry = select(name, symbol)
            key = (name, entry.start, entry.end)
            if key not in seen:
                seen.add(key)
                units.append((name, entry, entry.start, entry.end, 'Explicit test'))
        if args.offset > len(units):
            raise ValueError('offset is beyond the last caller/test body')
        print('Lexical investigation: no receiver/type resolution or indirect-call coverage; test invocations are not coverage proof.')
        print('Scope: ' + ', '.join(args.scope))
        print(f'sha256:{identity} (scoped inputs)')
        budget = args.max_lines

        def display(name, entry, start, end, role):
            nonlocal budget
            label = entry.name if entry else 'file-scope invocation'
            print(f'{role}: {name}:{start}-{end} {label}')
            if end - start + 1 > budget:
                command = ['python3', 'Scripts/agent-read.py', name, '--lines', f'{start}:{end}']
                print('  Body omitted (line budget); read: ' + shlex.join(command))
                return
            budget -= end - start + 1
            print('  Complete lexical declaration:' if entry else '  Invocation line only:')
            for number in range(start, end + 1):
                print(f'{number}: {lines[name][number - 1]}')

        if args.offset == 0:
            display(args.path, target, target.start, target.end, 'Selected declaration')
            owners = [e for e in entries(args.path) if e != target and e.start <= target.start and e.end >= target.end]
            for owner in sorted(owners, key=lambda e: e.start):
                print(f'Enclosing context (signature only): {owner.name} [{owner.start}:{owner.end}]')
                print('  ' + ' '.join(owner.signature.split()))
        stop = min(len(units), args.offset + args.limit)
        for unit in units[args.offset:stop]:
            display(*unit)
        print(f'Caller/test bodies {args.offset}:{stop} of {len(units)}; omitted {len(units) - stop} after this page.')
        if stop < len(units):
            command = ['python3', 'Scripts/agent-investigate.py', '--path', args.path, '--symbol', args.symbol,
                       '--limit', str(args.limit), '--max-lines', str(args.max_lines), '--offset', str(stop), '--expect', identity]
            for scope in args.scope:
                command += ['--scope', scope]
            for test in args.test:
                command += ['--test', test]
            print('Continue: ' + shlex.join(command))
        for task in load_tasks(root):
            if args.path in task['sources']:
                print('Indexed test pointers (inspect assertions; discovery may require another scope): ' + ', '.join(task['tests']))
        return 0
    except (OSError, ValueError, RuntimeError, SyntaxError, UnicodeError, subprocess.SubprocessError) as error:
        parser.exit(2, f'Investigation failed: {error}\nTry: python3 Scripts/agent-read.py {shlex.quote(args.path)} --outline\n')


if __name__ == '__main__':
    raise SystemExit(main())
