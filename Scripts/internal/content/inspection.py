"""Bounded content relationship hints, derived from schemas and authored references."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from internal.content.content_codegen_triggers import parse_trigger_values
from internal.content.modifier_schema import modifier_definitions
from internal.markdown import headings


def related_references(root: Path, records: list[tuple]) -> list[str]:
    symbols, names = set(), set()
    trigger_fields, modifier_cases = set(), set()
    definitions = {row['token']: row['case'] for row in modifier_definitions(root / 'Scripts/internal/content/modifiers.json')}
    for _, identity, fields in records:
        symbols.add(identity)
        if fields.get('symbol'):
            symbols.add(fields['symbol'].rsplit('.', 1)[-1])
        names.add(fields.get('name', fields.get('title', '')))
        for key, value in fields.items():
            if key.endswith('triggers'):
                trigger_fields.update(parse_trigger_values(value, identity))
            elif key.endswith('modifiers'):
                for token in value.split('|'):
                    token = token.split(':', 1)[0].removeprefix('hero.').removeprefix('companion.')
                    if token in definitions:
                        modifier_cases.add(definitions[token])
    symbols.update(trigger_fields | modifier_cases)
    rows = []
    schemas = sorted((root / 'Scripts/internal/content/trigger_families').glob('*.json'))
    schemas += [root / 'Scripts/internal/content/modifiers.json']
    for path in schemas:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            match = re.search(r'"(name|case)":\s*"([^"]+)"', line)
            if match and match[2] in (trigger_fields if match[1] == 'name' else modifier_cases):
                rows.append(f'Schema: {path.relative_to(root)}:{number} — {match[2]}')
    guide = root / 'Docs/AgentContext/battle-talents.md'
    if guide.exists():
        lines = guide.read_text().splitlines()
        entries = headings(lines)
        for entry in entries:
            if entry.level < 3:
                continue
            text = ' '.join(' '.join(lines[entry.start - 1:entry.end]).split()).casefold().replace('’', "'")
            matched = sorted(name for name in names if name and
                             re.search(r'(?<!\w)' + re.escape(name.casefold().replace('’', "'")) + r'(?!\w)', text))
            if matched:
                rows.append(f'Rule: {guide.relative_to(root)}#{entry.slug} — {", ".join(matched)}')
    if not symbols:
        return rows
    # Authored Swift only: IDs and parsed fields may use different spellings.
    inventory = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
    files = sorted({name for name in inventory if name.endswith('.swift') and '/Generated/' not in name
                    and '.generated.' not in name and (root / name).is_file() and not (root / name).is_symlink()})
    pattern = r'\b(?:' + '|'.join(re.escape(symbol) for symbol in sorted(symbols)) + r')\b'
    if files:
        result = subprocess.run(['rg', '--json', '--', pattern, *files], cwd=root, text=True, capture_output=True)
        if result.returncode not in (0, 1):
            raise ValueError(result.stderr.strip())
        hits = []
        for raw in result.stdout.splitlines():
            event = json.loads(raw)
            if event['type'] != 'match':
                continue
            data = event['data']
            name, line = data['path']['text'], data['line_number']
            surface = 'Test' if any(part == 'Tests' or part.endswith('TestSupport') or part == 'TrinketUITests'
                                    for part in Path(name).parts) else 'Source'
            matched = sorted({item['match']['text'] for item in data['submatches']})
            hits.append((surface, name, line, ', '.join(matched)))
        rows += [f'{surface}: {name}:{line} — {matched}' for surface, name, line, matched in sorted(hits)]
    # Give schemas, rules, implementations, and tests a chance on the first page.
    groups = [[row for row in rows if row.startswith(label + ':')] for label in ('Schema', 'Rule', 'Source', 'Test')]
    return [group[index] for index in range(max(map(len, groups), default=0))
            for group in groups if index < len(group)]
