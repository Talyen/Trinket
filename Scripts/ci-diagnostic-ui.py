#!/usr/bin/env python3
"""Run selected UI diagnostics against a completed run's exact compiled products."""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def api(repository: str, suffix: str, field: str | None = None):
    command = ['gh', 'api']
    if field:
        command += ['--paginate', '--slurp']
    result = json.loads(subprocess.check_output([*command, f'repos/{repository}/actions/{suffix}'], text=True, timeout=90))
    return [item for page in result for item in page[field]] if field else result


def source_proof(run: dict, jobs: list[dict], artifacts: list[dict], repository: str, branch: str) -> dict:
    sha, attempt, run_id = run.get('head_sha'), run.get('run_attempt'), run.get('id')
    if (run.get('status') != 'completed' or run.get('path') != '.github/workflows/ci.yml'
            or run.get('head_branch') != branch or run.get('head_repository', {}).get('full_name') != repository
            or not isinstance(sha, str) or not re.fullmatch('[0-9a-f]{40}', sha)
            or type(attempt) is not int or attempt < 1 or type(run_id) is not int):
        raise ValueError('Source must be a completed same-repository CI run on this branch')
    build = [job for job in jobs if job.get('name') == 'tests / Build and smoke UI']
    if len(build) != 1 or build[0].get('head_sha') != sha or not any(step.get('name') == 'Restore warm cache and build'
                                 and step.get('conclusion') == 'success' for step in build[0].get('steps', [])):
        raise ValueError('Source run has no successful app/test product build')
    build_attempt = build[0].get('run_attempt')
    if type(build_attempt) is not int or not 1 <= build_attempt <= attempt:
        raise ValueError('Invalid producing build attempt')
    name = f'build-derived-data-{run_id}-{build_attempt}'
    products = [artifact for artifact in artifacts if artifact.get('name') == name
                and artifact.get('expired') is False and type(artifact.get('id')) is int]
    if len(products) != 1:
        raise ValueError('Exact-attempt products are missing or expired; diagnostics never rebuild')
    return {'sha': sha, 'artifact': name, 'run': str(run_id), 'source_conclusion': run.get('conclusion')}


def selections(mode: str, text: str) -> list[str]:
    requested = text.split()
    if not requested or len(requested) > 16 or any(not re.fullmatch(r'(?:TrinketUITests/)?\w+(?:/test\w+)?(?:\(\))?', target)
                                               for target in requested):
        raise ValueError('Specify one to sixteen existing UI classes or Class/testMethod selectors')
    sys.path.insert(0, str(Path('Scripts').resolve()))
    spec = importlib.util.spec_from_file_location('diagnostic_target_retry', 'Scripts/ci_ui_retry.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    plan = 'Smoke' if mode == 'smoke' else 'FullUI'
    registry = subprocess.check_output(['python3', 'Scripts/check-testplan-sync.py', '--classes', plan], text=True).split()
    allowed = {name.removeprefix('TrinketUITests/') for name in registry}
    cases = module.expected_cases(requested)
    if not cases or any(case.split('/')[0] not in allowed for case in cases):
        raise ValueError('Selectors must belong to the source revision and chosen test plan')
    return cases


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    resolve = sub.add_parser('resolve')
    resolve.add_argument('run', type=int)
    execute = sub.add_parser('run')
    execute.add_argument('mode', choices=('smoke', 'ui'))
    args = parser.parse_args()
    if args.action == 'resolve':
        repository = os.environ['GITHUB_REPOSITORY']
        result = source_proof(api(repository, f'runs/{args.run}'),
                              api(repository, f'runs/{args.run}/jobs?filter=latest&per_page=100', 'jobs'),
                              api(repository, f'runs/{args.run}/artifacts?per_page=100', 'artifacts'),
                              repository, os.environ['GITHUB_REF_NAME'])
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(''.join(f'{key}={value}\n' for key, value in result.items()))
        return
    selected = selections(args.mode, os.environ['DIAGNOSTIC_TESTS'])
    # The existing transfer guard checks commit, SDK, toolchain, architecture and
    # source stamps. `false` is the explicit rebuild command: incompatibility fails.
    subprocess.run(['./Scripts/restore-ci-test-products.sh', '--downloaded', '--', 'false'], check=True)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as output:
            output.write(f"### Diagnostic only\n\nExact products from run {os.environ.get('SOURCE_RUN')} at "
                         f"`{os.environ.get('SOURCE_SHA')}`; original conclusions remain unchanged.\n\n"
                         + '\n'.join('- ' + target for target in selected) + '\n')
    # Assertion failures remain failures; do not apply infrastructure or assertion retries here.
    raise SystemExit(subprocess.call(['./Scripts/test.sh', args.mode, '--no-build', *selected],
                                    env={**os.environ, 'SKIP_GENERATE': '1', 'TRINKET_TARGETED_UI_RETRY': '1'}))


if __name__ == '__main__':
    main()
