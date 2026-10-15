#!/usr/bin/env python3
"""Run lightweight source policies through one fail-closed search/report boundary."""

import argparse
import os
import sys

from internal.cli import ROOT
from internal import mechanical_policy, module_policy
from internal.policy_scan import SourceScan, report

GATES = {
    'agent-invariants': (mechanical_policy.invariants, 'Agent invariant check failed:', 'Agent invariant check passed.', ''),
    'exclusivity-footguns': (mechanical_policy.exclusivity, 'Exclusivity footgun check found inout of a likely stored property:', 'Exclusivity footgun check passed.', ''),
    'module-boundaries': (module_policy.violations, 'Module boundary violations:', 'Module boundaries OK.', 'Module Boundary Violation'),
    'artwork-budget': (mechanical_policy.artwork, 'Artwork budget violations:', 'Artwork budgets OK (6 GB typical: 320/550, cache 160-260).', ''),
    'api-bans': (lambda scan: mechanical_policy.token_violations(scan, 'api-bans', ['Trinket', 'TrinketUITests', 'Packages']), 'API ban violations:', 'Platform API bans OK.\nSwift Testing migration gate: OK (no XCTest imports in unit targets)', 'API Ban'),
}
REMEDIATION = {
    'agent-invariants': 'Escape hatches: EntropyCheck / TestSleepCheck / PersistenceCheck / ConcurrencyCheck / ArtworkWorkingSetCheck: allow - <reason>.',
    'exclusivity-footguns': 'Copy the property to a local var, pass &local, then write back. Escape hatch: // ExclusivityCheck: allow - <reason> on a nearby line.',
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, epilog=' '.join(REMEDIATION.values()))
    parser.add_argument('gate', choices=GATES)
    args = parser.parse_args()
    os.chdir(ROOT)
    check, header, success, title = GATES[args.gate]
    try:
        return report(check(SourceScan(ROOT)), header, success, title, *([REMEDIATION[args.gate]] if args.gate in REMEDIATION else []))
    except (OSError, ValueError, RuntimeError) as error:
        print(f'Policy scan failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
