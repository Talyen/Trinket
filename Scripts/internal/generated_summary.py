"""Record-level navigation for known generated catalogs; never a consistency proof."""
from __future__ import annotations

import re
import shlex
from pathlib import Path


PATTERNS = {
    'CombatantTalentCatalog.generated.swift': r'"(?P<id>[^"\n]+)": CombatantTalentEffect\(',
    'ItemAffixCatalog.generated.swift': r'ItemAffixCatalog\.affix\(',
    'GameContentHomestead.generated.swift': r'HomesteadNodeDefinition\(',
}
# These generators emit ordinary escaped Swift strings, not raw/multiline literals.
TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|[()[\]{},]', re.S)


def catalog_records(name: str, source: str) -> tuple[dict, str]:
    if not source:
        return {}, ''
    if '#"' in source or '"""' in source:
        raise ValueError('unsupported string literal')
    records, surroundings, previous = {}, [], 0
    for match in re.finditer(PATTERNS[Path(name).name], source):
        opening = match.end() - 1
        stack, fields, start, end = ['('], [], opening + 1, None
        for token in TOKENS.finditer(source, opening + 1):
            value = token.group()
            if value.startswith('"'):
                continue
            if value in '([{':
                stack.append(value)
            elif value in ')]}':
                if not stack or stack.pop() != {')': '(', ']': '[', '}': '{'}[value]:
                    raise ValueError('unbalanced generated record')
                if not stack:
                    fields.append(source[start:token.start()])
                    end = token.end()
                    break
            elif value == ',' and len(stack) == 1:
                fields.append(source[start:token.start()])
                start = token.end()
        if end is None:
            raise ValueError('unterminated generated record')
        parsed = {}
        for field in fields:
            if not field.strip():
                continue
            label, separator, value = field.strip().partition(':')
            if not separator or not re.fullmatch(r'\w+', label) or label in parsed:
                raise ValueError('unrecognized generated field')
            parsed[label] = value.strip()
        identity = match.groupdict().get('id') or parsed.get('id', '').strip('"').removeprefix('.')
        if not identity or identity in records:
            raise ValueError('missing or duplicate record identity')
        records[identity] = (source.count('\n', 0, match.start()) + 1, parsed)
        surroundings.append(source[previous:match.start()] + '<record>')
        previous = end
    if not records:
        raise ValueError('no recognized catalog records')
    surroundings.append(source[previous:])
    return records, ''.join(surroundings)


def generated_summary(name: str, before: bytes, after: bytes, *, staged: bool = False) -> list[str]:
    expand = shlex.join(['python3', 'Scripts/agent-diff.py', '--generated',
                        *(['--staged'] if staged else []), '--paths', name])
    if Path(name).name not in PATTERNS:
        return [f'Summary unavailable for {name}: unsupported format; expand its generated patch.\n']
    try:
        old, old_structure = catalog_records(name, before.decode('utf-8'))
        new, new_structure = catalog_records(name, after.decode('utf-8'))
    except (UnicodeError, ValueError) as error:
        return [f'Summary unavailable for {name}: {error}; expand its generated patch.\n']
    units = [f'Generated record hints: {name} (not semantic proof; full patch: {expand})\n']
    for identity in sorted(old.keys() | new.keys()):
        if identity not in old:
            units.append(f'  Added {identity} at {name}:{new[identity][0]}\n')
        elif identity not in new:
            units.append(f'  Removed {identity} (old line {old[identity][0]})\n')
        else:
            old_fields, new_fields = old[identity][1], new[identity][1]
            for field in sorted(old_fields.keys() | new_fields.keys()):
                a, b = old_fields.get(field), new_fields.get(field)
                if a == b:
                    continue
                def brief(value):
                    value = '(absent)' if value is None else value.replace('\n', ' ')
                    return value if len(value) <= 160 else value[:160] + '… [shortened; expand patch]'
                units.append(f'  Changed {identity}.{field} at {name}:{new[identity][0]}: {brief(a)} → {brief(b)}\n')
    if list(old) != list(new):
        units.append('  Registration sequence changed (IDs added, removed, or reordered); review full patch.\n')
    if old_structure != new_structure:
        units.append('  Code outside recognized records changed; review full patch.\n')
    return units
