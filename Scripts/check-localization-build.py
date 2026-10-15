#!/usr/bin/env python3
"""CI-only cross-check of compiler-extracted keys and compiled bundle languages; never builds."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from internal.localization import FORMAT, inventory


def compiler_keys(directory: Path) -> dict[str, set[str]]:
    found = {}
    for path in directory.rglob('*.stringsdata'):
        data = json.loads(path.read_text())
        source = data.get('source', '')
        if source == 'ExtractedAppShortcutsMetadata':
            continue
        if not isinstance(data.get('tables'), dict):
            raise ValueError(f'{path}: unsupported compiler extraction schema')
        keys = data['tables'].get('Localizable', [])
        if not isinstance(keys, list) or any(not isinstance(item, dict) or 'key' not in item for item in keys):
            raise ValueError(f'{path}: unsupported Localizable extraction schema')
        found.setdefault(source, set()).update(item['key'] for item in keys if item['key'])
    return found


def nonlinguistic_key(key: str) -> bool:
    # Compiler extraction also emits numeric-only Text interpolation and separators.
    # String arguments remain inventoried: they can carry untranslated player copy.
    if any(match[2] == '@' or match[2].startswith('#@') for match in FORMAT.finditer(key)):
        return False
    literal = FORMAT.sub('', key)
    return '%' not in literal and not any(character.isalpha() for character in literal)


def verify(root: Path, derived: Path, app: Path) -> list[str]:
    config, catalogs, _ = inventory(root)
    extracted = compiler_keys(derived / 'Build/Intermediates.noindex')
    errors = []
    for name, catalog in catalogs.items():
        if name.startswith('Localization/'):
            continue
        parent = str(Path(name).parent.parent)
        prefixes = [parent] if parent.startswith('Packages/') else ['Trinket/App', 'Trinket/Features']
        observed = set().union(*(keys for source, keys in extracted.items()
                                 if any('/' + prefix + '/' in '/' + source for prefix in prefixes)))
        observed = {key for key in observed if not nonlinguistic_key(key)}
        expected = set(catalog['strings'])
        if not observed:
            errors.append(f'{parent}: no compiler extraction evidence; build with SWIFT_EMIT_LOC_STRINGS=YES')
        for key in sorted(observed - expected):
            errors.append(f'{parent}: compiler found unregistered display key {key!r}; use a stable L10n resource')
        for key in sorted(expected - observed):
            errors.append(f'{parent}/{key}: resource missing from compiler extraction')
        target = Path(parent).name
        bundles = [app] if parent.startswith('Trinket/') else list(app.glob(f'*_{target}.bundle'))
        if len(bundles) != 1:
            errors.append(f'{parent}: expected one compiled resource bundle in {app}')
            continue
        available = {path.stem for path in bundles[0].glob('*.lproj')}
        for locale in ['en', *config['locales']]:
            if locale not in available:
                errors.append(f'{bundles[0].name}: missing bundled language {locale}')
            elif not list((bundles[0] / f'{locale}.lproj').glob('Localizable.strings*')):
                errors.append(f'{bundles[0].name}: language {locale} is declared but its compiled String Catalog is missing')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--derived-data', type=Path, required=True)
    parser.add_argument('--app', type=Path, required=True)
    args = parser.parse_args()
    try:
        errors = verify(args.root, args.derived_data, args.app)
        if errors:
            print('\n'.join(errors), file=sys.stderr)
            return 1
        print('Localization build PASS: compiler coverage and all six bundle languages verified.')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Localization build check failed: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
