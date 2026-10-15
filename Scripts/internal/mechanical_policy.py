"""Mechanical Swift invariants; rule-specific decisions share search and context."""

from __future__ import annotations

import re

from internal import swift_policy
from internal.cli import read_env_arrays
from internal.policy_scan import SourceScan


def source_roots(scan: SourceScan) -> tuple[list[str], list[str]]:
    packages = read_env_arrays(scan.root / 'Scripts/build-inputs.env', ['TRINKET_TEST_PACKAGES'])['TRINKET_TEST_PACKAGES']
    tests = [f'Packages/{package}/Tests' for package in packages if (scan.root / f'Packages/{package}/Tests').is_dir()]
    return ['Trinket', 'TrinketUITests', *(f'Packages/{package}/Sources' for package in packages), *tests], tests


def token_violations(scan: SourceScan, check: str, roots: list[str]) -> list[str]:
    findings = []
    for path in swift_policy.candidate_paths(check, roots, scan.root):
        relative = path.relative_to(scan.root)
        try:
            tokens = swift_policy.formatter_tokens(scan.text(path), scan.root)
        except (OSError, RuntimeError, ValueError) as error:
            raise RuntimeError(f'{relative}: {error}') from error
        findings.extend(scan.location(path, line - 1, message)
                        for line, message in swift_policy.violations(check, tokens, relative))
    return findings


def invariants(scan: SourceScan) -> list[str]:
    roots, tests = source_roots(scan)
    engine = ['Packages/BattleEngine/Sources/BattleEngine']
    rules = (
        (r'\b(Date|UUID)\(\)', engine, 'EntropyCheck', '', 'unseeded Date()/UUID() in BattleEngine rule code'),
        (r'\.random\(', engine, 'EntropyCheck', 'using:', 'unseeded .random( in BattleEngine rule code (inject RNG via using:)'),
        (r'Task\.sleep', tests, 'TestSleepCheck', '.milliseconds(', 'Task.sleep in package tests must poll with .milliseconds or use TestSleepCheck: allow'),
        (r'try\?', ['Packages/TrinketPersistence/Sources/TrinketPersistence'], 'PersistenceCheck', '', 'try? on persistence write/open; use an explicit path or PersistenceCheck: allow'),
        (r'@unchecked Sendable|nonisolated\(unsafe\)', roots, 'ConcurrencyCheck', '', '@unchecked Sendable / nonisolated(unsafe) needs a nearby Concurrency-Safety: rationale'),
        ('releasePins', ['Trinket/App/TrinketApp.swift'], 'ArtworkWorkingSetCheck', '', 'do not release launch artwork pins after warmup (ArtworkWorkingSetCheck)'),
    )
    findings = []
    for pattern, paths, marker, permitted, message in rules:
        for path, index, line in scan.matches(pattern, *paths):
            if line.lstrip().startswith('//') or permitted and permitted in line or scan.allowed(path, index, marker):
                continue
            if marker == 'ConcurrencyCheck' and scan.nearby(path, index, 'Concurrency-Safety:'):
                continue
            findings.append(scan.location(path, index, message))
    findings.extend(token_violations(scan, 'swiftlint-reasons', roots))
    for tenant in sorted((scan.root / 'Packages').iterdir()):
        if tenant.is_dir() and not (tenant / 'Package.swift').is_file() and not (tenant / 'Sources').is_dir():
            findings.append(f'{tenant.relative_to(scan.root)}/: package husk without Package.swift or Sources (remove the stale fold leftover)')
    return findings


def exclusivity(scan: SourceScan) -> list[str]:
    roots, _ = source_roots(scan)
    findings = []
    for pattern in (r'&self\.', r'into:\s*&[A-Za-z_]'):
        for path, index, line in scan.matches(pattern, *roots):
            if scan.allowed(path, index, 'ExclusivityCheck'):
                continue
            if pattern.startswith('into:'):
                identifier = re.findall(r'into:\s*&([A-Za-z_][A-Za-z0-9_]*)', line)[-1]
                lines = scan.lines(path)
                start = next((i for i in range(index, -1, -1) if re.search(r'(^|\s)func\s', lines[i])), max(0, index - 60))
                declaration = rf'\svar\s+{identifier}(\s*:\s*[^=]+)?\s*=|(into\s+)?{identifier}:\s*inout\s'
                if any(re.search(declaration, prior) for prior in lines[start:index]):
                    continue
            findings.append(scan.location(path, index, line))
    return findings


def artwork(scan: SourceScan) -> list[str]:
    path = 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/PreparedArtworkCache.swift'
    text = scan.text(scan.root / path)
    rules = (
        (r'residentArtworkByteCount = 320 \* 1024 \* 1024', 'residentArtworkByteCount must be 320 MiB (6 GB typical). See PerformanceInvestigationPlaybook § Artwork Budgets.'),
        (r'steadyStateProcessByteCount = 550 \* 1024 \* 1024', 'steadyStateProcessByteCount must be 550 MiB (6 GB typical).'),
        (r'^\s*return min\(max\(adaptiveBudget, 160 \* 1024 \* 1024\), 260 \* 1024 \* 1024\)', 'NSCache adaptive budget must stay clamped to 160-260 MiB.'),
    )
    return [f'{path}: {message}' for pattern, message in rules if not re.search(pattern, text, re.MULTILINE)]
