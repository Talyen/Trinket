#!/usr/bin/env python3
"""Scope package cache paths and report tenant footprints without reading build contents."""

import argparse
import os
from pathlib import Path
import re

from internal.cli import ROOT, write_json_atomic
from internal.output_retention import metadata, safe_path


def cache_paths(root: Path, packages: list[str], native_only: bool) -> list[str]:
    if not packages or len(set(packages)) != len(packages):
        raise ValueError('Select unique package names')
    for package in packages:
        if (not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', package)
                or not (root / 'Packages' / package / 'Package.swift').is_file()):
            raise ValueError(f'Unknown package: {package}')
    paths = [f'.DerivedData/host/{package}' for package in sorted(packages)]
    if not native_only:
        paths += [f'.DerivedData/packages/{package}' for package in sorted(packages)]
    return [*paths, '.DerivedData/build-source-times.json']


def footprint(root: Path, packages: list[str], native_only: bool, label: str, key: str) -> dict:
    selected = cache_paths(root, packages, native_only)
    tenants = []
    for kind in ('host', 'packages'):
        parent = root / '.DerivedData' / kind
        if not safe_path(parent, root) or not parent.is_dir():
            continue
        for path in sorted(parent.iterdir()):
            if path.is_symlink() or not path.is_dir():
                continue
            relative = str(path.relative_to(root))
            newest, size = metadata(path)
            tenants.append({'path': relative, 'allocatedBytes': size, 'newestWriteEpoch': newest,
                            'includedInCache': relative in selected})
    return {'schema': 1, 'label': label, 'packages': packages, 'nativeOnly': native_only,
            'cacheKey': key, 'sourceCommit': os.environ.get('GITHUB_SHA'),
            'cachePaths': selected, 'tenants': tenants,
            'includedTenantAllocatedBytes': sum(row['allocatedBytes'] for row in tenants if row['includedInCache']),
            'excludedTenantAllocatedBytes': sum(row['allocatedBytes'] for row in tenants if not row['includedInCache']),
            'limits': ['Allocated tenant sizes do not measure archive transfer bytes or cache hit rate.',
                       'Missing tenants are normal before their build backend runs; no caches were deleted.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('paths', 'report'))
    parser.add_argument('--packages', nargs='+', required=True)
    parser.add_argument('--native-only', choices=('true', 'false'), default='false')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--label', default='package-cache')
    parser.add_argument('--cache-key', default='unavailable')
    args = parser.parse_args()
    try:
        native = args.native_only == 'true'
        if args.mode == 'paths':
            print('\n'.join(cache_paths(ROOT, args.packages, native)))
        else:
            if args.output is None or args.output.exists() or args.output.is_symlink():
                raise ValueError('Select a new output report')
            report = footprint(ROOT, args.packages, native, args.label, args.cache_key)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            write_json_atomic(args.output, report)
            print(f"{args.label}: {report['includedTenantAllocatedBytes']} allocated tenant bytes selected; "
                  f"{report['excludedTenantAllocatedBytes']} excluded.")
    except (OSError, ValueError) as error:
        parser.exit(1, f'Package cache inventory failed: {error}\n')


if __name__ == '__main__':
    main()
