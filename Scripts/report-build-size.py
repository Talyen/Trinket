#!/usr/bin/env python3
"""Report built resources and optionally export device-thinned size evidence; never upload."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

from internal.cli import write_json_atomic
from internal.output_retention import metadata


def catalog_report(entries: list[dict]) -> dict:
    groups = Counter()
    counts = Counter()
    decoded = Counter()
    largest = []
    for entry in entries:
        if 'SizeOnDisk' not in entry:
            continue
        key = '/'.join(str(entry.get(field, 'none')) for field in ('AssetType', 'Encoding', 'Compression'))
        groups[key] += entry['SizeOnDisk']
        counts[key] += 1
        if entry.get('Encoding') == 'HEIF':
            kind = 'thumbnail' if entry.get('Name', '').endswith('_thumb') else 'full'
            decoded[kind] += entry.get('PixelWidth', 0) * entry.get('PixelHeight', 0) * 4
        largest.append({'name': entry.get('Name'), 'bytes': entry['SizeOnDisk'],
                        'encoding': entry.get('Encoding'), 'deploymentTarget': entry.get('DeploymentTarget')})
    return {'groups': [{'kind': key, 'count': counts[key], 'bytes': groups[key]} for key in sorted(groups)],
            'estimatedFullCatalogRGBABytes': dict(decoded),
            'largestRenditions': sorted(largest, key=lambda item: item['bytes'], reverse=True)[:15]}


def app_report(app: Path) -> dict:
    if app.is_symlink() or not app.is_dir():
        raise ValueError('Select an existing app bundle without a symlink root')
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    logical = Counter()
    files = 0
    for path in app.rglob('*'):
        if path.is_file() and not path.is_symlink():
            logical[str(path.relative_to(app)).split('/')[0]] += path.stat().st_size
            files += 1
    report = {'bundleIdentifier': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
              'build': info['CFBundleVersion'], 'xcodeBuild': info.get('DTXcodeBuild'),
              'sdk': info.get('DTSDKName'), 'minimumOS': info.get('MinimumOSVersion'),
              'logicalBytes': sum(logical.values()), 'allocatedBytes': metadata(app)[1], 'fileCount': files,
              'resources': dict(logical.most_common())}
    catalog = app / 'Assets.car'
    if catalog.is_file():
        report['catalog'] = catalog_report(json.loads(subprocess.check_output(
            ['xcrun', 'assetutil', '--info', str(catalog)], text=True, timeout=60)))
    return report


def export_thinned(archive: Path, output: Path) -> dict:
    """This opt-in signs a local diagnostic export with existing credentials only."""
    options = output / 'ExportOptions.plist'
    with options.open('wb') as stream:
        plistlib.dump({'method': 'debugging', 'destination': 'export',
                      'thinning': '<thin-for-all-variants>', 'manageAppVersionAndBuildNumber': False,
                      'signingStyle': 'automatic'}, stream)
    # No provisioning updates, upload destination or authentication credentials.
    # Large exports are temporary; keep only the native size report and diagnostics.
    with tempfile.TemporaryDirectory(prefix='thinned-', dir=output) as temporary:
        with (output / 'export.log').open('w') as log:
            subprocess.run(['xcodebuild', '-exportArchive', '-archivePath', str(archive),
                            '-exportPath', temporary, '-exportOptionsPlist', str(options)],
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=240)
        reports = list(Path(temporary).rglob('App Thinning Size Report.txt'))
        if len(reports) != 1:
            raise ValueError('Export produced no unique device-thinned size report')
        target = output / reports[0].name
        shutil.copy2(reports[0], target)
        return {'status': 'measured', 'report': target.name}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument('--app', type=Path)
    target.add_argument('--archive', type=Path)
    parser.add_argument('--output', type=Path, required=True, help='new evidence directory; never overwrite')
    parser.add_argument('--source-commit', help='exact revision established by the build producer')
    parser.add_argument('--export-thinned', action='store_true', help='expressly requested local export, or CI only')
    args = parser.parse_args()
    if args.source_commit and not re.fullmatch(r'[0-9a-f]{40}', args.source_commit):
        parser.error('--source-commit requires a full commit SHA')
    if args.export_thinned and not args.archive:
        parser.error('--export-thinned requires --archive')
    if args.export_thinned and os.environ.get('CI') != 'true' and os.environ.get('TRINKET_ALLOW_HEAVY_LOCAL') != '1':
        parser.error('Local export requires express authorization, TRINKET_ALLOW_HEAVY_LOCAL=1 and the shared host lane')
    try:
        args.output.mkdir(parents=True, exist_ok=False)
        archive = args.archive.resolve(strict=True) if args.archive else None
        apps = list((archive / 'Products/Applications').glob('*.app')) if archive else [args.app]
        if len(apps) != 1:
            raise ValueError('Archive must contain exactly one application')
        report = {'schema': 1, 'status': 'inspected', 'app': app_report(apps[0]),
                  'deviceThinned': {'status': 'not measured'},
                  'limits': ['Universal app bytes are not device download/install size.',
                             'Catalog RGBA estimates are not measured resident RAM.']}
        if args.source_commit:
            report['source'] = {'commit': args.source_commit, 'authority': 'build producer'}
        receipt = archive.parent / 'receipt.json' if archive else None
        if receipt and receipt.is_file():
            saved = json.loads(receipt.read_text())
            if (str(saved['build']) != str(report['app']['build']) or saved['version'] != report['app']['version']
                    or saved['bundle_id'] != report['app']['bundleIdentifier']
                    or (args.source_commit and saved['commit'] != args.source_commit)):
                raise ValueError('Adjacent receipt identifies a different build')
            report['source'] = {key: saved.get(key) for key in ('commit', 'xcode', 'version', 'build')}
        write_json_atomic(args.output / 'build-size.json', report)
        if args.export_thinned:
            report['deviceThinned'] = export_thinned(archive, args.output)
            write_json_atomic(args.output / 'build-size.json', report)
        print(json.dumps(report, indent=2))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Build size measurement incomplete: {error}\n')


if __name__ == '__main__':
    main()
