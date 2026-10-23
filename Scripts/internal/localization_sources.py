"""Authored content inventory and detection of untranslated literal UI labels."""
from __future__ import annotations

import csv
from copy import deepcopy
import json
from pathlib import Path
import re


MANIFEST_FIELDS = {
    'combatants': ('name',), 'enemies': ('name',), 'item_bases': ('name',),
    'traits': ('name', 'description'), 'talents': ('name', 'description'),
    'homestead_nodes': ('title', 'summary', 'stage_name', 'bonus_title', 'bonus_description'),
    'affixes': ('title', 'basic_description', 'astral_description'),
    'stages': ('chapter_title', 'encounter_art_title'),
}
DISPLAY_CALL = re.compile(r'\b(Text|Button|Menu|Label|Link|Toggle|Picker|Section|ProgressView|navigationTitle|accessibilityLabel|accessibilityValue|accessibilityHint|accessibilityAction)\(\s*(?:(?:balanced|named):\s*)?"([^"\n]*)')


def manifest_entries(root: Path) -> dict:
    entries = {}
    for manifest, fields in MANIFEST_FIELDS.items():
        path = root / f'ContentManifest/{manifest}.tsv'
        if not path.exists():
            continue
        with path.open() as stream:
            for row in csv.DictReader(stream, delimiter='\t'):
                identifier = row.get('id', row.get('node_id', row.get('chapter_id')))
                if not identifier:
                    raise ValueError(f'{path}: missing content identity')
                suffix = '.' + row['tier'] if 'tier' in row else ''
                for field in fields:
                    if field not in row:
                        raise ValueError(f'{path}: missing localizable field {field}')
                    text = row[field].replace('\\n', '\n')
                    if not text:
                        continue
                    key = f'{manifest}.{identifier.replace("-", "_").lower()}{suffix}.{field}'
                    entry = {'text': text, 'context': f'{path.relative_to(root)}: {identifier}{suffix}, {field}'}
                    if key in entries and entries[key]['text'] != text:
                        raise ValueError(f'{path}: conflicting English source for {key}')
                    entries[key] = entry
    # Reuse the authored ability declaration contract; reject declarations it cannot inventory.
    for path in sorted((root / 'Packages/TrinketContent/Sources/TrinketContent/Abilities').glob('AbilityCatalog+*.swift')):
        source = path.read_text()
        matches = list(re.finditer(r'static let (\w+) = Ability\(\s*id: "([^"]+)",\s*name: "([^"]+)",\s*tier:', source))
        count = len(re.findall(r'static let \w+ = Ability\(', source))
        if len(matches) != count:
            raise ValueError(f'{path.relative_to(root)}: unsupported ability declaration; extend localization inventory')
        for match in matches:
            symbol, identifier, text = match.groups()
            entries[f'ability.{identifier.replace("-", "_")}.name'] = {
                'text': text, 'context': f'{path.relative_to(root)}: {symbol} name'}
    return entries


def spire_sources(root: Path) -> dict:
    entries = {}
    directory = root / 'Packages/TrinketContent/Sources/TrinketContent/Encounters'
    literal = r'"(?:[^"\\]|\\.)*"'
    path = directory / 'SpireCatalog.swift'
    if path.exists():
        declaration = re.search(r'static let spires:\s*\[SpireDefinition\]\s*=\s*\[(.*?)^\s*\]', path.read_text(), re.M | re.S)
        if declaration is None:
            raise ValueError(f'{path.relative_to(root)}: unsupported Spire catalog; extend localization inventory')
        source = declaration[1]
        matches = list(re.finditer(r'\bspire\(\s*\.(\w+),\s*(' + literal + r'),\s*(' + literal + r'),\s*\.\w+\s*\)', source))
        if not matches or len(matches) != len(re.findall(r'\bspire\(', source)):
            raise ValueError(f'{path.relative_to(root)}: unsupported Spire declaration; extend localization inventory')
        for match in matches:
            for field, value in zip(('title', 'epithet'), match.groups()[1:]):
                key = f'spire.{match[1].lower()}.{field}'
                if key in entries or '\\(' in value:
                    raise ValueError(f'{path.relative_to(root)}: duplicate or interpolated Spire source {key}')
                entries[key] = {'text': json.loads(value), 'context': f'{path.relative_to(root)}: {match[1]}, {field}'}
    return entries


def difficulty_sources(root: Path) -> dict:
    entries = {}
    directory = root / 'Packages/TrinketContent/Sources/TrinketContent/Encounters'
    for filename, symbol, identity in [('Contracts.swift', 'ContractDifficulty', 'contract'), ('Voyage.swift', 'VoyageDifficulty', 'voyage')]:
        path = directory / filename
        if not path.exists():
            continue
        declaration = re.search(r'public enum ' + symbol + r':[^{]+\{(.*?)public var title: String \{\s*rawValue\.capitalized\s*\}', path.read_text(), re.S)
        if declaration is None:
            raise ValueError(f'{path.relative_to(root)}: unsupported difficulty titles; extend localization inventory')
        cases = [case.strip() for row in re.findall(r'^\s*case ([^\n]+)', declaration[1], re.M) for case in row.split(',')]
        if not cases or any(not re.fullmatch(r'[a-z]+', case) for case in cases):
            raise ValueError(f'{path.relative_to(root)}: unsupported difficulty case; extend localization inventory')
        for case in cases:
            entries[f'difficulty.{identity}.{case}.title'] = {
                'text': case.capitalize(), 'context': f'{path.relative_to(root)}: {symbol}.{case}, title'}
    return entries


def content_sources(root: Path, *, bootstrap_keys: dict | None = None) -> dict:
    entries = manifest_entries(root)
    legacy = root / 'Localization/legacy-content.json'
    if legacy.exists():
        for key, text in json.loads(legacy.read_text()).items():
            entries['legacy.' + key] = {
                'text': text, 'context': f'Localization/legacy-content.json: saved equipment description {key}'}
    entries.update(spire_sources(root))
    entries.update(difficulty_sources(root))
    aliases_path = root / 'Localization/source-keys.json'
    aliases = json.loads(aliases_path.read_text()) if aliases_path.exists() else {}
    anchors = {}
    legacy_keys = {}
    counts = {}
    def authored_key(path, field, offset, legacy):
        import hashlib
        before = path.read_text()[:offset]
        declarations = list(re.finditer(r'\b(?:static let|(?:static )?func) (\w+)', before))
        declaration = declarations[-1][1] if declarations else 'file'
        start = declarations[-1].start() if declarations else 0
        identities = re.findall(r'\bid: "([a-zA-Z0-9_-]+)"', before[start:])
        identity = identities[-1] if identities else declaration
        scope = f'{path.relative_to(root)}::{identity}::{field}'
        counts[scope] = counts.get(scope, 0) + 1
        anchor = scope + f'::{counts[scope]}'
        key = aliases.get(anchor, 'authored.' + hashlib.sha256(anchor.encode()).hexdigest()[:16])
        if key in legacy_keys and legacy_keys[key] != legacy:
            raise ValueError(f'{path.relative_to(root)}: shared localization key {key} now has conflicting English; remove its edited source-keys.json alias to split this entry')
        legacy_keys[key] = legacy
        anchors[anchor] = legacy
        return key
    directory = root / 'Packages/TrinketContent/Sources/TrinketContent'
    for path in sorted(directory.rglob('*.swift')):
        if 'Generated' in path.parts:
            continue
        for match in re.finditer(r'\b(name|title|description|displayName|narrative|label):\s*("(?:[^"\\]|\\.)*")', path.read_text()):
            if '\\(' in match[2]:
                if path.name != 'InventoryItem+Compatibility.swift':
                    raise ValueError(f'{path.relative_to(root)}: interpolated {match[1]} requires a typed localization adapter')
                continue
            text = json.loads(match[2])
            if not text or not re.search('[A-Za-z]', text):
                continue
            import hashlib
            identity = hashlib.sha256((path.name + match[1] + text).encode()).hexdigest()[:16]
            entries[authored_key(path, match[1], match.start(), f'authored.{identity}')] = {'text': text, 'context': f'{path.relative_to(root)}: {match[1]}'}
    for path in sorted((directory / 'Encounters/Mystery').glob('*.swift')):
        for match in re.finditer(r'\("[a-z0-9_-]+",\s*("(?:[^"\\]|\\.)*"),\s*\[', path.read_text()):
            text = json.loads(match[1])
            import hashlib
            identity = hashlib.sha256((path.name + 'choice' + text).encode()).hexdigest()[:16]
            entries[authored_key(path, 'choice', match.start(), f'authored.{identity}')] = {'text': text, 'context': f'{path.relative_to(root)}: Mystery choice label'}
    for path in sorted((root / 'Packages/TrinketAppState/Sources/TrinketAppState/Play').rglob('*.swift')):
        source = path.read_text()
        literals = list(re.finditer(r'\b(title|message):\s*("(?:[^"\\]|\\.)*")', source))
        literals += list(re.finditer(r'\b(\w+Message) = ("(?:[^"\\]|\\.)*")', source))
        for match in literals:
            if '\\(' in match[2]:
                raise ValueError(f'{path.relative_to(root)}: dynamic failure copy needs a typed localization adapter')
            text = json.loads(match[2])
            import hashlib
            identity = hashlib.sha256((str(path.relative_to(root)) + match[1] + text).encode()).hexdigest()[:16]
            entries[authored_key(path, match[1], match.start(), f'authored.{identity}')] = {'text': text, 'context': f'{path.relative_to(root)}: player-facing failure {match[1]}'}
    compatibility = directory / 'Equipment/InventoryItem+Compatibility.swift'
    if compatibility.exists():
        for match in re.finditer(r'\bdescription\s*[:=]\s*("(?:[^"\\]|\\.)*")', compatibility.read_text()):
            literal = match[1]
            result = ''
            cursor = 0
            while cursor < len(literal):
                if literal[cursor:cursor + 2] != '\\(':
                    result += literal[cursor]
                    cursor += 1
                    continue
                start = cursor + 2
                end, depth = start, 1
                while end < len(literal) and depth:
                    if literal[end] == '(': depth += 1
                    if literal[end] == ')': depth -= 1
                    end += 1
                expression = literal[start:end - 1]
                if depth or not (
                    expression in {'actual', 'percent'}
                    or expression.startswith(('CombatRounding.rounded(', 'Self.wholePercent('))
                ):
                    raise ValueError(f'{compatibility.relative_to(root)}: unsupported description interpolation {expression!r}; add a typed adapter')
                result += '1'
                cursor = end
            text = json.loads(result)
            key = authored_key(compatibility, 'compatibility-description', match.start(), 'authored.compatibility_' + __import__('hashlib').sha256(text.encode()).hexdigest()[:16])
            entries[key] = {'text': text, 'context': f'{compatibility.relative_to(root)}: canonical numeric compatibility description'}
    # Computed display labels keep canonical English out of persisted identifiers.
    # Keyword-dependent descriptions have a finite domain; enumerate that domain,
    # rather than trying to infer a keyword from translated prose at runtime.
    keyword_path = root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift'
    keywords = re.findall(r'case \w+ = "([^"]+)"', keyword_path.read_text())[:17]
    for path in sorted(directory.rglob('*.swift')):
        if 'Generated' in path.parts or path.name.endswith(('Validator.swift', '+Localization.swift')):
            continue
        source = path.read_text()
        for declaration in re.finditer(r'^(    )(?:public )?var (title|displayName|description|primaryActionTitle): String \{\n(.*?)^    \}', source, re.M | re.S):
            if declaration[2] == 'primaryActionTitle':
                case = r'case\s+\.\w+(?:\s*,\s*\.\w+)*\s*:\s*"(?:[^"\\]|\\.)*"'
                remainder = re.sub(case, '', declaration[3])
                if not re.fullmatch(r'\s*switch self\s*\{\s*\}\s*', remainder):
                    raise ValueError(f'{path.relative_to(root)}: unsupported primaryActionTitle; extend localization inventory')
            for literal in re.finditer(r'"(?:[^"\\]|\\.)*"', declaration[3]):
                text = literal[0][1:-1]
                if '\\(' in text:
                    if set(re.findall(r'\\\(([^)]+)\)', text)) != {'keyword.rawValue'}:
                        raise ValueError(f'{path.relative_to(root)}: unsupported computed {declaration[2]} interpolation; add a typed resource adapter')
                    variants = [text.replace('\\(keyword.rawValue)', keyword) for keyword in keywords]
                else:
                    variants = [text]
                for variant in variants:
                    value = json.loads('"' + variant + '"')
                    if not re.search('[A-Za-z]', value):
                        continue
                    import hashlib
                    identity = hashlib.sha256((path.name + declaration[2] + value).encode()).hexdigest()[:16]
                    case = re.findall(r'case ([^:\n]+):', declaration[3][:literal.start()])
                    field = declaration[2] + ':' + (case[-1] if case else 'value') + ':' + str(variants.index(variant))
                    entries[authored_key(path, field, declaration.start(), f'authored.{identity}')] = {'text': value, 'context': f'{path.relative_to(root)}: computed {declaration[2]}'}
    if bootstrap_keys is not None:
        bootstrap_keys.update(anchors)
    return entries


def numeric_source(text: str) -> str:
    # Legacy rolled powers spell a count of one as an article. Match canonical
    # data at this boundary; translated prose is never an input to rule parsing.
    return re.sub(r'\ba (debuff|buff)\b', r'1 \1', text)


def plural_sources(text: str) -> dict[str, str]:
    text = numeric_source(text)
    first = re.search(r'\d+', text)
    noun = re.search(r'\d+ (cards?|debuffs?|buffs?|turns?|rounds?)\b', text)
    if not noun or not first or first.start() != noun.start():
        return {'value': text}
    word = noun[1].rstrip('s')
    return {form: text[:noun.start(1)] + word + suffix + text[noun.end(1):]
            for form, suffix in [('one', ''), ('other', 's')]}


def marked_template(root: Path, text: str) -> tuple[str, list[int]]:
    keyword_source = (root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift').read_text()
    keywords = {term: identifier.lower() for identifier, term in re.findall(r'case (\w+) = "([^"]+)"', keyword_source)[:17]}
    keywords.update({'Burning': 'burn', 'Poisoned': 'poison', 'Bleeding': 'bleed', 'Frozen': 'freeze', 'Stunned': 'stun'})
    text = numeric_source(text)
    escaped = text.replace('%', '%%')
    pattern = r'(?<!\w)(' + '|'.join(re.escape(term) for term in sorted(keywords, key=len, reverse=True)) + r')(?!\w)'
    escaped = re.sub(pattern, lambda match: f'<keyword id="{keywords[match[0]]}">{match[0]}</keyword>', escaped)
    numbers = []
    def number(match):
        numbers.append(int(match[0]))
        return f'<value id="quantity_{len(numbers)}">%{len(numbers)}$lld</value>'
    # Identifiers in semantic tags contain digits; only replace text, never markup.
    pieces = re.split(r'(<[^>]+>)', escaped)
    escaped = ''.join(piece if piece.startswith('<') else re.sub(r'\d+', number, piece) for piece in pieces)
    return escaped, numbers


def content_catalog(root: Path, previous: dict) -> dict:
    catalog = {'sourceLanguage': 'en', 'version': '1.0', 'strings': {
        key: deepcopy(entry) for key, entry in previous.get('strings', {}).items() if key.startswith('rule.')
    }}
    for key, source in sorted(content_sources(root).items()):
        from internal.localization import localized
        forms = {}
        for form, text in plural_sources(source['text']).items():
            template, _ = marked_template(root, text)
            if 'narrative' in source['context']:
                template = template.replace('{A}', '“%1$@”').replace('{B}', '“%2$@”')
            forms[form] = template
        entry = deepcopy(previous.get('strings', {}).get(key, {}))
        entry['extractionState'] = 'manual'
        entry['comment'] = source['context']
        entry['localizations'] = entry.get('localizations', {})
        entry['localizations']['en'] = localized(forms)
        catalog['strings'][key] = entry
    return catalog


def canonical_argument_errors(source: str) -> list[tuple[int, str]]:
    """Reject direct canonical display fields in typed translation arguments.

    This is a bounded source guard, not type inference: local variables and custom
    adapters still need behavior tests. Keep strings opaque when splitting calls
    so punctuation in prose does not change argument boundaries. `displayName`
    is intentionally excluded: presentation models already localize that property.
    """
    token = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[(),]|[^()",/]+|.', re.S)
    canonical = r'(?:[A-Za-z_$]\w*\s*\.\s*)+(?:name|title|description|rawValue)'
    argument = re.compile(r'\s*(?:' + canonical + r'|"\\\(\s*' + canonical + r'\s*\)")\s*')
    errors = []
    # Mask comments without changing offsets or line numbers.
    source = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"',
                    lambda match: re.sub(r'[^\n]', ' ', match[0]) if match[0].startswith(('//', '/*')) else match[0],
                    source, flags=re.S)
    code = re.sub(r'"(?:\\.|[^"\\])*"', lambda match: re.sub(r'[^\n]', ' ', match[0]), source)
    for call in re.finditer(r'\bL10n\.\w+\s*\(', code):
        depth, start = 1, call.end()
        for match in token.finditer(source, start):
            value = match[0]
            if value == '(':
                depth += 1
            elif value == ')':
                depth -= 1
            if (value == ',' and depth == 1) or depth == 0:
                if argument.fullmatch(source[start:match.start()]):
                    value_start = start + len(source[start:match.start()]) - len(source[start:match.start()].lstrip())
                    line = source.count('\n', 0, value_start) + 1
                    errors.append((line, 'canonical content argument must be localized before interpolation; use ContentCopy or an identity-based localized name in the rendering locale'))
                start = match.end()
            if depth == 0:
                break
    return errors


def source_errors(root: Path, *, paths: set[Path] | None = None, check_content: bool = True) -> list[str]:
    errors = []
    config = json.loads((root / 'Localization/config.json').read_text())
    content_path = config.get('contentCatalog')
    if content_path and check_content:
        catalog = json.loads((root / content_path).read_text())
        if catalog != content_catalog(root, catalog):
            errors.append(f'{content_path}: authored content changed; run localization.py plan and apply the reviewed queue')
    catalogs = {name: json.loads((root / name).read_text()) for name in config['catalogs']}
    owners = {}
    for name, catalog in catalogs.items():
        if name.startswith('Localization/'):
            continue
        scope = str(Path(name).parent.parent)
        owners[scope] = {key.replace('.', '_') for key in catalog['strings']}
        if name.startswith('Trinket/'):
            owners['Trinket/Features'] = owners[scope]
    for directory in ('Trinket/App', 'Trinket/Features', 'Packages'):
        for path in sorted((root / directory).rglob('*.swift')):
            if paths is not None and path.resolve() not in paths:
                continue
            if 'Tests' in path.parts or 'Generated' in path.parts or path.name.endswith('.generated.swift'):
                continue
            source = path.read_text()
            errors.extend(f'{path.relative_to(root)}:{number}: {message}'
                          for number, message in canonical_argument_errors(source))
            for number, line in enumerate(source.splitlines(), 1):
                if line.lstrip().startswith('//'):
                    continue
                relative = str(path.relative_to(root))
                symbols = next((symbols for scope, symbols in owners.items() if relative.startswith(scope + '/')), None)
                for symbol in re.findall(r'\bL10n\.(\w+)', line):
                    if symbols is None or symbol not in symbols:
                        errors.append(f'{relative}:{number}: unknown typed localization resource L10n.{symbol}')
                if 'privacy:' in line and 'L10n.' in line:
                    errors.append(f'{relative}:{number}: OSLog privacy interpolation cannot be localized')
                if re.search(r'case\s+\w+\s*=.*L10n\.|category:.*L10n\.|accessibilityIdentifier\([^)]*L10n\.', line):
                    errors.append(f'{relative}:{number}: localization must not replace raw identities, logging categories, or accessibility selectors')
                for match in DISPLAY_CALL.finditer(line):
                    if re.search('[A-Za-z]', re.sub(r'\\\([^)]*\)', '', match[2])):
                        errors.append(f'{path.relative_to(root)}:{number}: {match[1]} has an unlocalized literal; use its target L10n resource')
    return errors
