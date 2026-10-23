#!/usr/bin/env python3
"""Execute or preview the same task-scoped verification plan."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

from internal.change_routing import Check, collect_paths, classify, verification_plan, automatic_plan, lightweight
from internal.cli import ROOT, pinned_tool_path, write_json_atomic, read_env_arrays
from internal.ui_registration import registrations
from internal import output_retention as retention
from internal.verification_evidence import source_identity, toolchain_identity


def save_report(root: Path, route: str, paths: list[str], checks, outcomes: dict[str, str], status: int, *, identity: str | None = None, toolchain: dict | None = None) -> Path:
    """Preserve compact execution evidence separately from disposable phase logs."""
    directory = root / '.DerivedData/Deliverables/Verification'
    if any(path.is_symlink() for path in (directory, *directory.parents) if path.is_relative_to(root)):
        raise ValueError('Verification deliverables cannot follow symlinks')
    directory.mkdir(parents=True, exist_ok=True)
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, capture_output=True)
    dirty = subprocess.run(['git', 'status', '--porcelain', '--untracked-files=all'], cwd=root, text=True, capture_output=True)
    report = directory / f'{route}-{uuid.uuid4().hex}.json'
    write_json_atomic(report, {
        'local_state': 'checks passed' if status == 0 else 'verification incomplete',
        'hosted_state': 'pending; requires an authorized push and successful hosted checks',
        'source_identity': identity, 'toolchain': toolchain,
        'version': 2, 'recorded_at': datetime.now(timezone.utc).isoformat(),
        'route': route, 'exit_status': status,
        'commit': revision.stdout.strip() if revision.returncode == 0 else None,
        'workspace_status': dirty.stdout.splitlines() if dirty.returncode == 0 else None,
        'inputs': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() if (root / name).is_file() else None
                   for name in paths},
        'checks': [{'id': check.id, 'command': check.command, 'argv': list(check.argv),
                    'outcome': outcomes.get(check.id, 'deferred to CI' if check.deferred else 'not run')}
                   for check in checks],
        'visual_review': 'separate shipping-UI evidence required when visuals change',
    })
    print(f'Verification report (preserved during integration): {report}')
    return report


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
            if (check.id == 'build' or check.id.startswith('package:') or check.id == 'package') and shutil.which('xcodebuild', path=environment.get('PATH')) is None:
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
            print('Handoff INCOMPLETE: selected compilation requires xcodebuild; available checks passed.', file=sys.stderr)
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


def report_evidence(checks, outcomes: dict[str, str], *, preview: bool, status: int, route: str = 'static') -> None:
    def state(selected) -> str:
        if not selected:
            return 'not selected'
        states = {('deferred to CI' if check.deferred else 'planned') if preview
                  else outcomes.get(check.id, 'not run') for check in selected}
        return ', '.join(value for value in ('failed', 'unavailable', 'not run', 'planned', 'passed', 'deferred to CI') if value in states)
    print('Verification evidence' + (' (preview)' if preview else '') + ':')
    print('Route: ' + route)
    if route == 'visual':
        print('Managed inspection session: ' + state([check for check in checks if check.id == 'visual']))
        print('App build/launch: inspect the managed runner output.')
        print('UI behavior: separate interaction evidence required.')
    elif route == 'release':
        print('Release verification: ' + state([check for check in checks if check.id == 'release']))
        print('Static, app/package compilation and UI results: inspect the release runner report.')
    else:
        print('Static checks: ' + state([check for check in checks if check.id not in {'package', 'build', 'smoke', 'generate', 'assert', 'mirror'} and not check.id.startswith('package:')]))
        print('App compilation: ' + state([check for check in checks if check.id == 'build']))
        print('Package compilation and behavior: ' + state([check for check in checks if check.id == 'package' or check.id.startswith('package:')]))
        print('UI behavior: ' + state([check for check in checks if check.id == 'smoke']))
    print('Hosted verification: pending until successful hosted evidence is available.')
    print('Visual review: separate shipping-UI evidence required when visuals change; handoff does not certify it.')
    if status:
        print('Next: resolve failed/unavailable checks and rerun handoff.')
    elif preview:
        print('Next: execute this handoff to establish the planned evidence.')
    elif route not in {'static', 'auto'}:
        print('Next: review the captured results; focused verification and inspection do not replace static handoff or hosted qualification.')
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
    parser.add_argument('--route', choices=('auto', 'static', 'focused', 'diagnostic', 'visual', 'release'),
                        help='auto/static run lightweight local checks and defer compiled work to CI; focused local execution requires an explicit heavy-local opt-in')
    target = parser.add_mutually_exclusive_group()
    target.add_argument('--package', nargs='+', help='focused: run selected packages serially')
    target.add_argument('--ui', help='focused: run one existing UI class or method selector')
    target.add_argument('--app-only', action='store_true', help='focused: compile the app only')
    for flag in ('dry-run', 'quiet', 'isolate', 'smoke', 'mirror', 'final', 'keep-plan'):
        parser.add_argument('--' + flag, action='store_true')
    args = parser.parse_args(argv)
    if args.paths is None and not args.working_tree and args.base is None:
        args.base = 'main'
    if args.paths == []:
        parser.error('--paths requires at least one repository-relative path')
    selected = bool(args.package or args.ui or args.app_only)
    args.route = args.route or ('focused' if selected else 'static' if args.mirror else 'auto')
    if args.route == 'diagnostic':
        args.route = 'focused'
    if selected != (args.route == 'focused'):
        parser.error('focused verification requires exactly one of --package, --ui, --app-only')
    if args.route not in {'static', 'auto'} and (args.smoke or args.mirror or args.final or args.keep_plan):
        parser.error('--smoke, --mirror, --final and --keep-plan apply only to auto/static checks')
    environment = dict(os.environ)
    environment['PATH'] = pinned_tool_path(root, environment.get('PATH', ''))
    if not environment.get('TRINKET_DIAGNOSTICS_SESSION_ID'):
        environment['TRINKET_DIAGNOSTICS_SESSION_ID'] = environment.get('TRINKET_RUN_ID') or (
            datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + f'-{os.getpid()}-{uuid.uuid4().hex[:8]}'
        )
    # Agent verification always isolates; retain --isolate for existing callers.
    environment['TRINKET_ISOLATE'] = '1'
    try:
        route = classify(collect_paths(args.paths, root, base=args.base), root, base=args.base)
        if not route.paths and args.route in {'static', 'auto'}:
            print('No changes in the selected scope to verify; no new evidence established.')
            return 0
        if args.route == 'auto' and args.mirror:
            raise ValueError('--mirror requires --route static or the legacy unqualified --mirror invocation')
        if args.route == 'auto':
            checks = automatic_plan(route, root=root, environment=environment, final=args.final, keep_plan=args.keep_plan)
        elif args.route == 'static':
            planning_environment = environment if environment.get('GITHUB_ACTIONS') == 'true' else {**environment, 'TRINKET_ALLOW_HEAVY_LOCAL': ''}
            checks = verification_plan(route, root=root, environment=planning_environment, smoke=args.smoke or environment.get('TRINKET_ENABLE_SMOKE') == 'true', final=args.final, keep_plan=args.keep_plan, mirror=args.mirror)
        else:
            if args.route == 'visual':
                # Shipping-UI inspection remains a bounded local exception.
                environment['TRINKET_ALLOW_HEAVY_LOCAL'] = '1'
            elif not args.dry_run and lightweight(environment):
                raise ValueError('Compilation and tests are CI-owned. Use ./Scripts/handoff.sh --quiet. '
                                 'Only for an expressly requested local diagnostic or release run, '
                                 'set TRINKET_ALLOW_HEAVY_LOCAL=1 with the explicit selector.')
            if args.route == 'focused':
                if args.package:
                    known = set(read_env_arrays(root / 'Scripts/build-inputs.env', ['TRINKET_TEST_PACKAGES'])['TRINKET_TEST_PACKAGES'])
                    if not set(args.package) <= known or len(args.package) != len(set(args.package)):
                        raise ValueError('--package requires distinct registered package names')
                    environment['TRINKET_PACKAGE_TEST_JOBS'] = '1'
                    checks = [Check('package:' + package, 'focused package verification: ' + package,
                                    ('./Scripts/test-package.sh', package)) for package in args.package]
                elif args.ui:
                    suite = next((row['suite'] for row in registrations(root)
                                  if row['name'] == args.ui.partition('/')[0]), None)
                    if suite not in {'Smoke', 'FullUI'}:
                        raise ValueError('--ui requires one registered Smoke or FullUI Class[/method] selector')
                    mode = 'smoke' if suite == 'Smoke' else 'ui'
                    checks = [Check('smoke', 'focused UI verification', ('./Scripts/test.sh', mode, args.ui))]
                else:
                    checks = [Check('build', 'focused app compilation', ('./Scripts/test.sh', 'unit', '--app-only'))]
            elif args.route == 'visual':
                checks = [Check('visual', 'managed visual inspection', ('./Scripts/run-simulator.sh', '--isolate', '--inspect'))]
            else:
                environment['TRINKET_ALLOW_FULL_UI'] = '1'
                checks = [Check('release', 'full release verification', ('./Scripts/test-deploy.sh', '--mode', 'ui'))]
            print(f'Explicit {args.route} route: ' + checks[0].command, flush=True)
        if any(check.id == 'build' and not check.deferred for check in checks):
            print('App compilation selection:')
            for reason in route.compile_reasons or ['app/UI, package manifest, public contract, or explicit app selector']:
                print('  ' + reason)
        outcomes = {}
        if args.dry_run:
            print('Planned checks:')
            for check in checks:
                if not check.deferred:
                    if (check.id == 'build' or check.id.startswith('package:') or check.id == 'package') and shutil.which('xcodebuild', path=environment.get('PATH')) is None:
                        print(f'Unavailable required check: {check.label} (xcodebuild missing).')
                    else:
                        print('  ' + check.command)
            status = 0
        else:
            if args.route == 'visual':
                deliverables = root / '.DerivedData/Deliverables'
                deliverables.mkdir(parents=True, exist_ok=True)
                print(f'Task deliverables (preserved during integration): {deliverables}', flush=True)
            compiled = bool(shutil.which('xcodebuild', path=environment.get('PATH'))) and any(
                not check.deferred and (check.id == 'build' or check.id.startswith('package:')) for check in checks)
            identity = source_identity(root) if compiled else None
            toolchain = toolchain_identity(root) if compiled else None
            status = run_checks(checks, root=root, quiet=args.quiet and args.route != 'visual', environment=environment, outcomes=outcomes)
            if compiled and source_identity(root) != identity:
                status = status or 2
                identity = None
                print('Source changed during verification; compiled evidence is invalid. Rerun the requested diagnostic.', file=sys.stderr)
            save_report(root, args.route, route.paths, checks, outcomes, status, identity=identity, toolchain=toolchain)
        deferred = [check.command for check in checks if check.deferred]
        if deferred:
            print('Deferred to CI:')
            print('\n'.join('  ' + command for command in deferred))
        report_evidence(checks, outcomes, preview=args.dry_run, status=status, route=args.route)
        if status:
            print('Rerun: ' + shlex.join(['./Scripts/handoff.sh', *(sys.argv[1:] if argv is None else argv)]), file=sys.stderr)
        elif not args.dry_run:
            if args.route not in {'static', 'auto'}:
                print(f'{args.route.capitalize()} route completed; see evidence above for its scope.')
            else:
                print('Handoff PASS: selected local checks completed; hosted verification remains pending.')
        return status
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f'Verification failed: {error}\n')


if __name__ == '__main__':
    raise SystemExit(main())
