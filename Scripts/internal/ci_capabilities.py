"""Runner availability and honest coverage receipts, separate from test success."""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import uuid

UNAVAILABLE_MARKER = '[ci capability unavailable]'


class CapabilityUnavailable(RuntimeError):
    """The runner cannot supply a requested environment; no product verdict exists."""


def available_profiles(runtimes, device_types, devices, *, family='iPhone', preferred_device='',
                       major=None, sdk_version='', excluded=()):
    """Rank installed compatible choices, preferring a booted device and the active SDK."""
    def version(value):
        parts = tuple(int(part) for part in value.split('.'))
        return parts + (0,) * (3 - len(parts))

    sdk = version(sdk_version) if sdk_version else ()
    known = {item['identifier']: item.get('name', item['identifier']) for item in device_types}
    candidates = []
    for runtime in runtimes:
        if (runtime.get('platform') != 'iOS' or runtime.get('isAvailable') is not True
                or runtime.get('identifier') in excluded or not re.fullmatch(r'\d+(?:\.\d+)*', runtime.get('version', ''))
                or version(runtime['version'])[0] < 26):
            continue
        supported = {item['identifier'] for item in runtime.get('supportedDeviceTypes', [])}
        for type_id, name in known.items():
            if family not in name or (family != 'Duo' and 'Duo' in name) or (supported and type_id not in supported):
                continue
            existing = [item for item in devices.get(runtime['identifier'], [])
                        if item.get('deviceTypeIdentifier') == type_id and item.get('isAvailable', True)]
            existing.sort(key=lambda item: (item.get('state') != 'Booted', item.get('udid', '')))
            device = existing[0] if existing else {}
            current = version(runtime['version'])
            score = (device.get('state') == 'Booted', major is None or current[0] == major,
                     not sdk or current <= sdk, bool(existing), type_id == preferred_device,
                     not runtime.get('buildversion', '')[-1:].islower(), current, type_id)
            profile = dict(device=type_id, runtime=runtime['identifier'], version=runtime['version'],
                           build=runtime.get('buildversion', ''), udid=device.get('udid', ''))
            candidates.append((score, profile))
    return [profile for _, profile in sorted(candidates, key=lambda item: item[0], reverse=True)]


def available_ui_selectors(selectors, profile, discover):
    """Keep real purchases; defer only the demonstrated StoreKit denial-service defect."""
    denied = 'FullGamePurchaseUITests/testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase'
    if profile.get('build') == '23C54':
        return list(selectors), []
    selected, deferred = [], []
    for selector in selectors:
        if selector == denied:
            deferred.append(selector)
        elif selector == denied.split('/')[0]:
            cases = discover([selector])
            if not cases:
                raise ValueError('Cannot establish the purchase class scope for capability selection.')
            selected.extend(case for case in cases if case != denied)
            if denied in cases:
                deferred.append(denied)
        else:
            selected.append(selector)
    return list(dict.fromkeys(selected)), deferred


def record_coverage(scope, status, reason='', *, environment=None, details=None):
    environment = dict(os.environ) if environment is None else environment
    root = Path(environment.get('DERIVED_DATA_PATH', '.DerivedData')) / 'CICoverage'
    root.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema=1, scope=scope, status=status, reason=reason, details=details or {},
                   commit=environment.get('GITHUB_SHA', ''), run=environment.get('GITHUB_RUN_ID', ''),
                   attempt=environment.get('GITHUB_RUN_ATTEMPT', ''),
                   xcode=environment.get('XCODE_BUILD', ''),
                   created_at=datetime.now(timezone.utc).isoformat())
    (root / f'{uuid.uuid4().hex}.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if path := environment.get('GITHUB_STEP_SUMMARY'):
        with Path(path).open('a') as output:
            output.write(f'\n### Coverage: {scope}\n\n**{status}**. {reason}\n\n')
            if details:
                output.write('```json\n' + json.dumps(details, indent=2) + '\n```\n')
    if status == 'unavailable':
        print(f'::warning::{UNAVAILABLE_MARKER} {scope}: {reason}', flush=True)
    return receipt


def unavailable_failure(results, before, additional_roots=()):
    """Only known infrastructure may become a gap; mixed or unknown failures stay red."""
    failed = []
    paths = {path for root in (results, *additional_roots) for path in root.rglob('*-invocation.json')}
    for path in paths:
        if before.get(path) == path.stat().st_mtime_ns:
            continue
        try:
            receipt = json.loads(path.read_text())
            # Nested scenarios can own their own session IDs. All fresh receipts
            # in this command's result roots must veto a mixed product failure.
            if receipt.get('status') == 'failed':
                if diagnostic := receipt.get('diagnostics_json'):
                    report = json.loads(Path(diagnostic).read_text())
                    if not isinstance(report, dict) or report.get('exit_code', receipt.get('exit_code')) != receipt.get('exit_code'):
                        return None
                    receipt = {**receipt, **{key: report[key] for key in
                               ('classification', 'issues', 'log', 'log_path', 'raw_log_path') if key in report}}
                failed.append(receipt)
        except (OSError, ValueError, AttributeError):
            return None
    if not failed:
        return None
    reasons = []
    for receipt in failed:
        try:
            log = Path(receipt.get('raw_log_path') or receipt.get('log_path') or receipt.get('log') or '').read_text(errors='replace')
        except OSError:
            log = ''
        # Fixture assertions and source diagnostics must not be softened by a
        # nearby boot error. XCTest/Swift Testing issues remain authoritative below.
        if re.search(r'XCTAssert\w*.*failed|XCTFail|XCTUnwrap.*failed|AssertionError:|'
                     r'\.(?:swift|swiftinterface|metal|m|mm|c|cc|cpp|h):\d+(?::\d+)?: (?:fatal )?error:', log):
            return None
        issues = receipt.get('issues', [])
        if not isinstance(issues, list) or any(not isinstance(issue, dict) for issue in issues):
            return None
        runtime_lost = any(issue.get('kind') == 'simulator-infrastructure' and
                           'unable to boot device because we cannot determine the runtime bundle' in issue.get('message', '').lower()
                           for issue in issues)
        termination = lambda issue: runtime_lost and re.fullmatch(
            r'Test crashed with signal (?:term|SIGTERM)\.', issue.get('message', ''), re.I)
        if any(issue.get('kind') == 'build-failure' or
               (issue.get('kind') == 'test-failure' and not termination(issue)) for issue in issues):
            return None
        typed_unavailable = receipt.get('exit_code') == 78 and UNAVAILABLE_MARKER in log
        lost_runtime_only = runtime_lost and all(issue.get('kind') == 'simulator-infrastructure' or termination(issue)
                                                for issue in issues)
        inventory_timeout = re.search(
            r"^Simulator guest process inspection failed: Command '\['ps', [^\n]+timed out after [\d.]+ seconds$",
            log, re.M)
        inventory_unavailable = bool(
            receipt.get('action') == 'prepare' and receipt.get('phase') == 'simulator-process-inventory'
            and receipt.get('classification') == 'tooling' and inventory_timeout and issues
            and all(issue.get('kind') == 'tooling' and issue.get('title') == 'Preparation inventory'
                    for issue in issues))
        if (receipt.get('classification') != 'simulator-infrastructure' and not typed_unavailable
                and not lost_runtime_only and not inventory_unavailable):
            return None
        detail = inventory_timeout[0] if inventory_unavailable else next(
            (issue.get('message', '') for issue in issues if issue.get('message')), '')
        if not detail:
            detail = next((line for line in log.splitlines() if UNAVAILABLE_MARKER in line or 'Error:' in line), '')
        reasons.append(receipt.get('label', 'simulator environment') + ': ' + ' '.join(detail.split())[:500])
    return 'Runner capability unavailable: ' + ', '.join(reasons)
