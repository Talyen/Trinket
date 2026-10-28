#!/usr/bin/env python3
"""Check discrete CI cache globs against the live, shell-expanded build inputs."""

import argparse
import re
import sys

from internal.cli import ROOT
from internal.policy_scan import report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('cache-roots', 'inputs', 'required-inputs', 'packages'):
        parser.add_argument('--' + name, nargs='+', required=True)
    args = parser.parse_args()
    try:
        source = (ROOT / '.github/actions/build-cache-key/action.yml').read_text()
        globs = {glob for call in re.findall(r'hashFiles\(([^)]*)\)', source)
                 for _, glob in re.findall(r'''(['"])(.*?)\1''', call)}
        if not globs:
            raise ValueError('no hashFiles globs found in build-cache-key')
        findings = [f'Missing discrete hashFiles glob in build-cache-key: {glob}'
                    for glob in args.cache_roots if glob not in globs]
        findings.extend(f'Missing shared build input: {path}' for path in args.required_inputs if path not in args.inputs)
        findings.extend(f'Missing package tenant in shared build inputs: Packages/{package}'
                        for package in args.packages if f'Packages/{package}' not in args.inputs)
        for key, required, forbidden in (
            ('full', ('Trinket/**', 'Packages/**', 'ContentManifest/**', 'Localization/**'), ()),
            ('nonsource', ('Scripts/tool-versions.env',), ('Scripts/**', 'ContentManifest/**', 'Localization/**')),
        ):
            line = next((line for line in source.splitlines() if key + '=' in line), None)
            if line is None:
                raise ValueError(f'missing {key}= hashFiles line in build-cache-key')
            findings.extend(f'build-cache-key {key} hashFiles must include {glob}' for glob in required if glob not in line)
            findings.extend(f'{key} hashFiles must not include {glob}; these edits should prefix-restore.'
                            for glob in forbidden if glob in line)
        return report(findings, 'check-build-cache-paths: path-list drift detected', 'Build input / cache-key shared roots aligned.')
    except (OSError, ValueError) as error:
        print(f'check-build-cache-paths: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
