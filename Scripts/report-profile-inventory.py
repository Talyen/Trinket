#!/usr/bin/env python3
"""Inventory legacy profiling XML by metadata only; no deletion, hashing or compression."""

import argparse
from collections import Counter
import os
from pathlib import Path

from internal.build_symbols import artifact_root
from internal.cli import write_json_atomic

DERIVED_NAMES = {'toc.xml', 'samples.xml', 'symbolicated-samples.xml', 'atos-samples.xml', 'swiftui.xml'}


def protection(path: Path, root: Path) -> list[str]:
    reasons = set()
    for parent in path.parents:
        if not parent.is_relative_to(root):
            continue
        if (parent / '.retention-keep').exists() or (parent / '.retention-keep').is_symlink():
            reasons.add('explicit keep')
        if (parent / '.retention-owner.json').exists() or (parent / '.retention-owner.json').is_symlink():
            reasons.add('owner record requires verification')
    for suffix in ('.retention-keep', '.retention-owner.json'):
        marker = path.with_name(path.name + suffix)
        if marker.exists() or marker.is_symlink():
            reasons.add('file retention control')
    return sorted(reasons)


def trace_context(path: Path, root: Path) -> tuple[list[str], list[str]]:
    for parent in path.parents:
        if not parent.is_relative_to(root):
            break
        traces = sorted(p for p in parent.glob('*.trace') if p.is_dir() and not p.is_symlink())
        if traces:
            provenance = [str(p.relative_to(root)) for p in (parent / 'result.json', parent / 'symbol-manifest.json',
                          parent / 'protocol.json') if p.is_file() and not p.is_symlink()]
            return [str(p.relative_to(root)) for p in traces], provenance
    return [], []


def inventory(root: Path) -> dict:
    if root.is_symlink() or root.resolve() != root or not root.is_dir():
        raise ValueError('Select an existing profiling root without symlink ancestors')
    counts = Counter()
    logical = Counter()
    allocated = Counter()
    candidates = []
    skipped = []
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in list(dirs):
            path = Path(base) / name
            if path.is_symlink():
                skipped.append(str(path.relative_to(root)))
                dirs.remove(name)
        for name in files:
            path = Path(base) / name
            if path.is_symlink():
                skipped.append(str(path.relative_to(root)))
                continue
            if path.suffix != '.xml':
                continue
            stat = path.stat()
            in_trace = any(part.endswith('.trace') for part in path.relative_to(root).parts[:-1])
            kind = 'raw-trace-component' if in_trace else 'derived-export-candidate' if name in DERIVED_NAMES else 'unknown-XML'
            counts[kind] += 1
            logical[kind] += stat.st_size
            allocated[kind] += stat.st_blocks * 512
            if kind == 'derived-export-candidate':
                traces, provenance = trace_context(path, root)
                blocked = protection(path, root)
                if len(traces) != 1:
                    blocked.append('no unique adjacent raw trace')
                if not provenance:
                    blocked.append('no adjacent provenance record')
                candidates.append({'path': str(path.relative_to(root)), 'logicalBytes': stat.st_size,
                    'allocatedBytes': stat.st_blocks * 512, 'modifiedAtEpoch': stat.st_mtime,
                    'rawTraces': traces, 'provenance': provenance, 'protection': blocked,
                    'nextStep': 'verify regeneration recipe, capture identity and idle ownership before any migration'})
    return {'schema': 1, 'mode': 'metadata-only; no deletion authorized by this report', 'root': str(root),
            'groups': [{'kind': k, 'count': counts[k], 'logicalBytes': logical[k], 'allocatedBytes': allocated[k]}
                       for k in sorted(counts)],
            'candidates': sorted(candidates, key=lambda row: row['logicalBytes'], reverse=True),
            'skippedSymlinks': skipped, 'eligibleForDeletionBytes': 0,
            'limits': ['Filenames and adjacent traces do not prove that an export is reproducible.',
                       'No file contents, hashes, process inventories or open-file state were inspected.',
                       'Raw traces, unknown XML, keep controls and provenance remain unchanged.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=artifact_root() / 'profiles')
    parser.add_argument('--output', type=Path, required=True, help='new JSON report outside the profiling root')
    args = parser.parse_args()
    try:
        root = args.root.absolute()
        if args.output.exists() or args.output.is_symlink() or args.output.resolve().is_relative_to(root):
            raise ValueError('Output must be a new report outside the profiling root')
        report = inventory(root)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        write_json_atomic(args.output, report)
        print(f"Inventoried {sum(row['count'] for row in report['groups'])} XML files; "
              f"{len(report['candidates'])} candidates need review; zero bytes eligible for deletion.")
    except (OSError, ValueError) as error:
        parser.exit(1, f'Profile inventory incomplete: {error}\n')


if __name__ == '__main__':
    main()
