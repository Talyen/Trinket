#!/usr/bin/env python3
"""Execute or preview the same task-scoped verification plan."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

from internal.change_routing import collect_paths, classify, verification_plan, lightweight
from internal.cli import ROOT, pinned_tool_path
from internal import output_retention as retention


def run_checks(checks, *, root: Path = ROOT, quiet: bool = False, environment: dict[str, str] | None = None, outcomes: dict[str, str] | None = None) -> int:
    environment = dict(os.environ if environment is None else environment)
    environment['PATH'] = pinned_tool_path(root, environment.get('PATH', ''))
    outcomes = {} if outcomes is None else outcomes
    logs = None
    managed = False
    status = 0
    unavailable = False
    try:
        for index, check in enumerate(checks, 1):
            if check.deferred:
                outcomes[check.id] = 'deferred to CI'
                continue
            if check.id == 'build' and shutil.which('xcodebuild', path=environment.get('PATH')) is None:
                unavailable = True
                outcomes[check.id] = 'unavailable'
                continue
            if quiet:
                if logs is None:
                    log_root = Path(environment.get('RESULTS_DIR', str(root / '.DerivedData/HandoffResults')))
                    log_root.mkdir(parents=True, exist_ok=True)
                    logs = Path(tempfile.mkdtemp(prefix='handoff.', dir=log_root))
                    if retention.managed_path(logs, root):
                        if environment.get('TRINKET_OUTPUT_RETENTION_READY') != '1':
                            retention.cleanup(root, apply=True, verbose=False)
                        retention.begin(logs, root, os.getpid())
                        managed = True
                    environment['TRINKET_OUTPUT_RETENTION_READY'] = '1'
                    print(f'Handoff logs: {logs}', flush=True)
                log = logs / f'phase-{index}.log'
                with log.open('w') as stream:
                    try:
                        status = subprocess.run(check.argv, cwd=root, env={**environment, **dict(check.environment)}, stdout=stream, stderr=subprocess.STDOUT).returncode
                    except OSError as error:
                        status = 2
                        print(f'Could not start {check.command}: {error}', file=stream)
                print(f'Handoff phase {"PASS" if status == 0 else "FAIL"}: {check.label} (phase-{index}.log)', flush=True)
                if status:
                    print(f'Full log: {log}', file=sys.stderr)
                    subprocess.run(['python3', 'Scripts/script_diagnostics.py', str(log)], cwd=root)
            else:
                print('=== ' + check.command + ' ===', flush=True)
                status = subprocess.run(check.argv, cwd=root, env={**environment, **dict(check.environment)}).returncode
            outcomes[check.id] = 'failed' if status else 'passed'
            if status:
                print(f'Handoff FAIL: {check.command} (exit {status})', file=sys.stderr)
                return status
        if unavailable:
            status = 2
            print('Handoff INCOMPLETE: app compilation requires xcodebuild; available checks passed.', file=sys.stderr)
        return status
    except BaseException:
        status = status or 1
        raise
    finally:
        if logs is not None and managed:
            if environment.get('TRINKET_KEEP_REPORTS') == '1':
                retention.marker(logs, retention.KEEP).touch()
            try:
                retention.finish(logs, root, os.getpid(), status, comparison=environment.get('TRINKET_CLEANUP_TEST_ARTIFACTS') == '0')
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                print(f'Log retention: {error}', file=sys.stderr)


def report_evidence(checks, outcomes: dict[str, str], *, preview: bool, status: int) -> None:
    def state(selected) -> str:
        if not selected:
            return 'not selected'
        states = {('deferred to CI' if check.deferred else 'planned') if preview
                  else outcomes.get(check.id, 'not run') for check in selected}
        return ', '.join(value for value in ('failed', 'unavailable', 'not run', 'planned', 'passed', 'deferred to CI') if value in states)
    print('Verification evidence' + (' (preview)' if preview else '') + ':')
    print('Static checks: ' + state([check for check in checks if check.id not in {'package', 'build', 'smoke', 'generate', 'assert', 'mirror'}]))
    print('App compilation: ' + state([check for check in checks if check.id in {'build', 'smoke'}]))
    print('Package compilation and behavior: ' + state([check for check in checks if check.id == 'package']))
    print('UI behavior: ' + state([check for check in checks if check.id == 'smoke']))
    print('Visual review: separate shipping-UI evidence required when visuals change; handoff does not certify it.')
    if status:
        print('Next: resolve failed/unavailable checks and rerun handoff.')
    elif preview:
        print('Next: execute this handoff to establish the planned evidence.')
    elif any(check.deferred for check in checks):
        print('Next: local integration is permitted after review; after an authorized push, inspect hosted CI for deferred checks.')
    else:
        print('Next: review the diff and integrate locally; push only when authorized.')


def main(argv: list[str] | None = None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument('--paths', nargs='+')
    scope.add_argument('--working-tree', action='store_true')
    scope.add_argument('--base', help='include task commits since the shared ancestor of REF and HEAD, plus dirty files')
    for flag in ('dry-run', 'quiet', 'isolate', 'smoke', 'mirror', 'final', 'keep-plan'):
        parser.add_argument('--' + flag, action='store_true')
    args = parser.parse_args(argv)
    if args.paths is None and not args.working_tree and args.base is None:
        parser.error('handoff requires --paths <file...> or --base <ref>; use --working-tree for intentional whole-tree scope')
    if args.paths == []:
        parser.error('--paths requires at least one repository-relative path')
    environment = dict(os.environ)
    environment['PATH'] = pinned_tool_path(root, environment.get('PATH', ''))
    if not environment.get('TRINKET_DIAGNOSTICS_SESSION_ID'):
        environment['TRINKET_DIAGNOSTICS_SESSION_ID'] = environment.get('TRINKET_RUN_ID') or (
            datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + f'-{os.getpid()}-{uuid.uuid4().hex[:8]}'
        )
    if args.isolate: environment['TRINKET_ISOLATE'] = '1'
    try:
        route = classify(collect_paths(args.paths, root, base=args.base), root, base=args.base)
        if not route.paths:
            print('No changes in the selected scope to verify; no new evidence established.')
            return 0
        checks = verification_plan(route, root=root, environment=environment, smoke=args.smoke or environment.get('TRINKET_ENABLE_SMOKE') == 'true', final=args.final, keep_plan=args.keep_plan, mirror=args.mirror)
        outcomes = {}
        if args.dry_run:
            print('Planned checks:')
            for check in checks:
                if not check.deferred:
                    if check.id == 'build' and shutil.which('xcodebuild', path=environment.get('PATH')) is None:
                        print('Unavailable required check: app compilation (xcodebuild missing).')
                    else:
                        print('  ' + check.command)
            status = 0
        else:
            status = run_checks(checks, root=root, quiet=args.quiet, environment=environment, outcomes=outcomes)
        deferred = [check.command for check in checks if check.deferred]
        if deferred:
            print('Deferred to CI:')
            print('\n'.join('  ' + command for command in deferred))
        report_evidence(checks, outcomes, preview=args.dry_run, status=status)
        if status:
            print('Rerun: ' + shlex.join(['./Scripts/handoff.sh', *(sys.argv[1:] if argv is None else argv)]), file=sys.stderr)
        elif not args.dry_run:
            print('Handoff PASS: lightweight local checks completed; deferred checks require CI verification.' if lightweight(environment) else 'Handoff PASS: selected checks and cheap CI slices completed.')
        return status
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f'Verification failed: {error}\n')


if __name__ == '__main__':
    raise SystemExit(main())
