"""Parse the shared ordered UI-test registry for generation and verification routing."""
from __future__ import annotations

import re
from pathlib import Path

from internal.cli import ROOT

SUITES = ('Smoke', 'FullUI', 'Profiles', 'Soak')

REGISTRY = 'Scripts/config/ui-tests.tsv'


def registrations(root: Path = ROOT) -> list[dict]:
    rows, classes, keys = [], set(), set()
    for number, line in enumerate((root / REGISTRY).read_text().splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('|')
        if len(parts) != 3:
            raise ValueError(f'{REGISTRY}:{number}: expected suite|key|class')
        suite, key, name = parts
        if (suite not in SUITES or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name)
                or (suite == 'Smoke' and not re.fullmatch(r'[A-Z][A-Z0-9_]*', key))
                or (suite != 'Smoke' and key)):
            raise ValueError(f'{REGISTRY}:{number}: invalid registration')
        if name in classes or (key and key in keys):
            raise ValueError(f'{REGISTRY}:{number}: duplicate class or routing key')
        classes.add(name)
        keys.add(key)
        rows.append(dict(suite=suite, key=key, name=name))
    if not {'Smoke', 'FullUI'}.issubset({row['suite'] for row in rows}):
        raise ValueError(f'{REGISTRY}: both Smoke and FullUI must be nonempty')
    return rows
