#!/usr/bin/env python3
"""Prove native Swift Testing execution and compare its scope with iOS."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess

from internal.diagnostics.diagnostic_model import (
    CLASSIFICATION_PRECEDENCE, DiagnosticIssue, IssueAccumulator, IssueObservation, MAX_ISSUES,
)
from internal.diagnostics.diagnostic_rendering import render_annotation
from internal.diagnostics.failure_diagnostics_parsers import parse_log
from internal.diagnostics.execution_identity import execution_identity, require_hosted_identity

PACKAGES = ('BattleEngine', 'TrinketCore')


def canonical(identifier: str, package: str) -> str:
    prefix = package + 'Tests.'
    if not identifier.startswith(prefix):
        raise ValueError(f'Unexpected native test module: {identifier}')
    # Swift Testing appends a source location after the function identifier.
    return identifier[len(prefix):].rsplit('/', 1)[0]


def execution(package: str, events: Path, catalog: Path) -> dict:
    functions = {}
    started, ended, cases, case_starts = Counter(), Counter(), Counter(), Counter()
    runs = finishes = 0
    for line in events.read_text().splitlines():
        record = json.loads(line)
        if record.get('version') != 0:
            raise ValueError('Unsupported Swift Testing event schema')
        payload = record['payload']
        kind = payload['kind']
        if record['kind'] == 'test' and kind == 'function':
            identifier = payload['id']
            if identifier in functions:
                raise ValueError('Duplicate native function declaration')
            if type(payload.get('isParameterized')) is not bool:
                raise ValueError('Missing parameterized-test discovery metadata')
            functions[identifier] = payload['isParameterized']
        elif record['kind'] == 'event':
            if kind in {'issueRecorded', 'testSkipped'}:
                raise ValueError(f'Native execution recorded {kind}')
            if kind == 'runStarted':
                runs += 1
            elif kind == 'runEnded':
                finishes += 1
            elif kind in {'testStarted', 'testEnded', 'testCaseStarted', 'testCaseEnded'}:
                destination = {'testStarted': started, 'testEnded': ended,
                               'testCaseStarted': case_starts, 'testCaseEnded': cases}[kind]
                destination[payload['testID']] += 1
    expected = [line.split('.', 1)[1] for line in catalog.read_text().splitlines()
                if line.startswith(package + 'Tests.')]
    if not functions or not runs or runs != finishes or case_starts != cases or len(expected) != len(set(expected)):
        raise ValueError('Native execution has incomplete or empty discovery/run evidence')
    if any(started[key] != 1 or ended[key] != 1 or (parameterized and not cases[key])
           for key, parameterized in functions.items()):
        raise ValueError('A native function did not execute and complete exactly once')
    actual = sorted(canonical(key, package) for key in functions)
    if actual != sorted(expected):
        raise ValueError('Native execution differs from the independently discovered catalog')
    case_counts = {canonical(key, package): cases[key] for key, parameterized in functions.items() if parameterized}
    return {'package': package, 'expected_tests': sorted(expected), 'executed_tests': actual,
            'parameterized_tests': sorted(case_counts), 'case_counts': case_counts,
            'passed': len(actual), 'failed': 0, 'skipped': 0, 'complete': True}


def valid(proof: object) -> bool:
    if not isinstance(proof, dict) or proof.get('package') not in PACKAGES or proof.get('complete') is not True:
        return False
    expected, executed = proof.get('expected_tests'), proof.get('executed_tests')
    parameters, counts = proof.get('parameterized_tests'), proof.get('case_counts')
    return (isinstance(expected, list) and bool(expected) and expected == executed
            and all(isinstance(name, str) and '/' in name for name in expected)
            and len(set(expected)) == len(expected)
            and isinstance(parameters, list) and all(isinstance(name, str) for name in parameters)
            and isinstance(counts, dict) and len(set(parameters)) == len(parameters)
            and set(parameters) == set(counts) and set(parameters).issubset(expected)
            and all(type(count) is int and count > 0 for count in counts.values())
            and type(proof.get('passed')) is int and proof['passed'] == len(expected)
            and type(proof.get('failed')) is int and proof['failed'] == 0
            and type(proof.get('skipped')) is int and proof['skipped'] == 0)


def failure_issues(events: Path, log: Path, exit_code: int) -> list[dict]:
    accumulator = IssueAccumulator()
    try:
        with events.open() as stream:
            for line in stream:
                record = json.loads(line)
                payload = record.get('payload', {})
                if (record.get('version') != 0 or record.get('kind') != 'event'
                        or payload.get('kind') != 'issueRecorded'):
                    continue
                issue = payload.get('issue', {})
                if issue.get('isKnown') is True:
                    continue
                messages = [item['text'] for item in payload.get('messages', [])
                            if isinstance(item, dict) and isinstance(item.get('text'), str)]
                location = issue.get('sourceLocation', payload.get('_sourceLocation', {}))
                accumulator.add(IssueObservation(
                    'test-failure', 'Swift Testing assertion', messages[0] if messages else 'Native test recorded an issue',
                    test=str(payload.get('testID', '')).rsplit('/', 1)[0],
                    file=str(location.get('_filePath', location.get('fileID', ''))),
                    line=location.get('line'), details='\n'.join(messages[1:]),
                ))
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        # Interrupted streams can still have useful assertions before their incomplete tail.
        pass
    for observation in parse_log(log, exit_code):
        if observation.kind != 'unknown':
            accumulator.add(observation)
    issues = accumulator.finalize()
    return [issue.to_dict() for issue in issues[:MAX_ISSUES]]


def compare(native: dict, rows: list[dict], commit: str) -> dict:
    proof = native.get('native_test')
    if (not valid(proof) or native.get('commit') != commit or native.get('status') != 'passed'
            or type(native.get('exit_code')) is not int or native['exit_code'] != 0 or native.get('issues')):
        raise ValueError('Native parity requires current-commit execution proof')
    candidates = [row for row in rows if row.get('mode') == 'package:' + proof['package']]
    if len(candidates) != 1:
        raise ValueError('Parity requires exactly one iOS comparator invocation')
    ios = candidates[0]
    summary, tests = ios.get('summary', {}), ios.get('tests', [])
    ids = [test['id'] for test in tests]
    ios_cases = {test['id']: len(test['arguments']) for test in tests if test.get('arguments')}
    if any(not isinstance(test.get('arguments'), list) or any(result != 'Passed' for result in test['arguments']) for test in tests):
        raise ValueError('iOS parameterized execution evidence is incomplete')
    if ios_cases != proof['case_counts']:
        raise ValueError('Native/iOS expanded parameterized case counts differ')
    if ios.get('commit') != commit:
        raise ValueError('iOS comparator lacks a same-revision commit receipt')
    if (any(type(summary.get(key)) is not int for key in ('passed', 'failed', 'skipped'))
            or summary.get('result') != 'Passed' or summary.get('failed') != 0 or summary.get('skipped') != 0
            or summary.get('passed') != proof['passed'] or len(ids) != len(set(ids))
            or sorted(ids) != proof['executed_tests'] or any(t.get('result') != 'Passed' for t in tests)):
        raise ValueError('Native/iOS executed test identities or results differ')
    return {'package': proof['package'], 'commit': commit, 'matched_tests': proof['passed'],
            'matched_parameterized_cases': sum(proof['case_counts'].values()),
            'native': 'passed', 'ios': 'passed'}


def ios_transfer(package: str, rows: list[dict], identity: dict) -> dict:
    require_hosted_identity(identity)
    candidates = [row for row in rows if row.get('mode') == 'package:' + package]
    if len(candidates) != 1:
        raise ValueError('Transfer requires exactly one iOS comparator invocation')
    row = candidates[0]
    summary, tests = row.get('summary', {}), row.get('tests', [])
    if (row.get('commit') != identity['commit'] or row.get('execution_identity') != identity
            or summary.get('result') != 'Passed' or type(summary.get('passed')) is not int
            or not tests or summary['passed'] != len(tests)
            or any(type(summary.get(key)) is not int or summary[key] != 0 for key in ('failed', 'skipped'))
            or any(not isinstance(test, dict) or test.get('result') != 'Passed'
                   or not isinstance(test.get('id'), str) or '/' not in test['id']
                   or not isinstance(test.get('arguments'), list)
                   or any(result != 'Passed' for result in test['arguments']) for test in tests)
            or len({test['id'] for test in tests}) != len(tests)):
        raise ValueError('Transfer requires complete successful same-run iOS execution evidence')
    return {'schema_version': 1, 'package': package, 'execution_identity': identity, 'ios': row}


def compare_transfer(native: dict, transfer: dict, identity: dict) -> dict:
    require_hosted_identity(identity)
    if (type(transfer.get('schema_version')) is not int or transfer['schema_version'] != 1
            or transfer.get('execution_identity') != identity or native.get('execution_identity') != identity
            or transfer.get('package') not in PACKAGES
            or native.get('native_test', {}).get('package') != transfer['package']):
        raise ValueError('Parity evidence differs in repository, revision, run, attempt, toolchain or package')
    validated = ios_transfer(transfer['package'], [transfer['ios']], identity)
    return compare(native, [validated['ios']], identity['commit'])


def write_receipt(output: Path, result: dict) -> None:
    result = {'schema_version': 1, 'generated_at': datetime.now(timezone.utc).isoformat(),
              'session_id': os.environ.get('TRINKET_DIAGNOSTICS_SESSION_ID', ''), **result}
    output.write_text(json.dumps(result) + '\n')
    output.with_name(result['label'] + '-invocation.json').write_text(
        json.dumps({**result, 'diagnostics_json': str(output)}) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    record = sub.add_parser('record')
    record.add_argument('package', choices=PACKAGES)
    for name in ('events', 'catalog', 'log', 'output'):
        record.add_argument(name, type=Path)
    record.add_argument('--exit-code', type=int, default=0)
    parity = sub.add_parser('compare')
    for name in ('native', 'timing', 'output'):
        parity.add_argument(name, type=Path)
    transfer = sub.add_parser('export-ios')
    transfer.add_argument('package', choices=PACKAGES)
    transfer.add_argument('timing', type=Path)
    transfer.add_argument('output', type=Path)
    transferred = sub.add_parser('compare-transfer')
    for name in ('native', 'ios', 'output'):
        transferred.add_argument(name, type=Path)
    args = parser.parse_args()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    identity = execution_identity(commit)
    if args.action == 'export-ios':
        result = ios_transfer(args.package, [json.loads(line) for line in args.timing.read_text().splitlines()], identity)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result) + '\n')
        return
    if args.action in ('compare', 'compare-transfer'):
        try:
            native = json.loads(args.native.read_text())
            if args.action == 'compare-transfer':
                result = compare_transfer(native, json.loads(args.ios.read_text()), identity)
            else:
                result = compare(native, [json.loads(line) for line in args.timing.read_text().splitlines()], commit)
        except (OSError, ValueError, KeyError, TypeError) as error:
            message = f'{args.native.name}: {error}'
            write_receipt(args.output.with_name('native-parity-diagnostics.json'),
                          {'label': 'native-parity', 'action': 'native-parity', 'status': 'failed',
                           'exit_code': 1, 'classification': 'configuration',
                           'issues': [{'kind': 'configuration', 'message': message}]})
            raise SystemExit(message)
        args.output.write_text(json.dumps(result) + '\n')
        print(f"Native/iOS parity: {result['package']} matched {result['matched_tests']} executed tests.")
        return
    issues, proof = [], None
    status = args.exit_code
    try:
        if status:
            raise ValueError(f'Native process exited {status}; see {args.log}')
        proof = execution(args.package, args.events, args.catalog)
    except (OSError, ValueError, KeyError, TypeError) as error:
        status = status or 1
        issues = failure_issues(args.events, args.log, status)
        if not issues:
            kind = 'unknown' if args.exit_code else 'configuration'
            issues = [dict(kind=kind, title='Native execution evidence', message=str(error))]
    kinds = {issue['kind'] for issue in issues}
    classification = next((kind for kind in CLASSIFICATION_PRECEDENCE if kind in kinds), 'unknown')
    result = {'schema_version': 1, 'label': 'native-' + args.package, 'action': 'native-test',
              'status': 'passed' if status == 0 else 'failed', 'exit_code': status,
              'classification': classification, 'issues': issues,
              'commit': commit, 'native_test': proof, 'test_execution_proven': status == 0,
              'execution_identity': identity,
              'native_artifacts': [str(args.events), str(args.catalog), str(args.log)],
              'completion_source': 'process-exit', 'raw_log_path': str(args.log),
              'generated_at': datetime.now(timezone.utc).isoformat(),
              'session_id': os.environ.get('TRINKET_DIAGNOSTICS_SESSION_ID', '')}
    write_receipt(args.output, result)
    if status:
        for issue in issues[:5]:
            print(f"Native {args.package} {issue['kind']}: {issue.get('test') or issue.get('file', '')} {issue['message']}", flush=True)
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            for issue in issues[:MAX_ISSUES]:
                print(render_annotation(DiagnosticIssue.from_observation(IssueObservation(
                    issue['kind'], issue.get('title', 'Native failure'), issue['message'],
                    test=issue.get('test', ''), file=issue.get('file', ''), line=issue.get('line'),
                ))))
        raise SystemExit(issues[0]['message'])
    print(f"Native {args.package}: {proof['passed']} discovered tests executed and passed.")


if __name__ == '__main__':
    main()
