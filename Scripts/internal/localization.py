"""Deterministic localization inventory and optimistic, transactional agent result application."""
from __future__ import annotations

from collections import Counter
from contextlib import contextmanager
from copy import deepcopy
import fcntl
from fnmatch import fnmatchcase
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile


REVIEW_CHECKS = {'meaning', 'mechanics', 'terminology', 'placeholders', 'grammar'}
PLURALS = {'en': {'one', 'other'}, 'ja': {'other'}, 'ko': {'other'},
           'de': {'one', 'other'}, 'zh-Hant': {'other'}, 'fr': {'one', 'many', 'other'}}
FORMAT = re.compile(r'%(?:(\d+)\$)?(?:[-+#0 ]*\d*(?:\.\d+)?)(lld|llu|ld|lu|d|u|f|g|@|#@[^@]+@|%)')


def digest(value) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def load(path: Path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'{path}: duplicate JSON key {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def encoded(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()


def encoded_catalog(catalog: dict) -> bytes:
    """Keep keys and context expanded, with each complete locale record on one line."""
    def render(value, depth=0, locales=False):
        if not isinstance(value, dict) or not value:
            return json.dumps(value, ensure_ascii=False, sort_keys=True)
        records = []
        for key, item in sorted(value.items()):
            text = json.dumps(item, ensure_ascii=False, sort_keys=True) if locales else render(item, depth + 2, key == 'localizations')
            records.append(' ' * (depth + 2) + json.dumps(key, ensure_ascii=False) + ': ' + text)
        return '{\n' + ',\n'.join(records) + '\n' + ' ' * depth + '}'
    return (render(catalog) + '\n').encode()


def encoded_reviews(receipts: dict) -> bytes:
    """Keep each locale's complete evidence on one line without changing the JSON schema."""
    def compact(value):
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
    entries = []
    for identifier, locales in sorted(receipts.items()):
        records = ',\n'.join(f'    {compact(locale)}: {compact(record)}' for locale, record in sorted(locales.items()))
        entries.append(f'  {compact(identifier)}: {{\n{records}\n  }}')
    return ('{\n' + ',\n'.join(entries) + '\n}\n').encode() if entries else b'{}\n'


def contained(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f'Localization path escapes repository: {name}')
    return path


def placeholders(text: str) -> Counter:
    if '%' in FORMAT.sub('', text):
        raise ValueError('Unsupported or unescaped percent format; use %% for a literal percent')
    result = Counter()
    consumed = 0
    for match in FORMAT.finditer(text):
        position, kind = match.groups()
        if kind == '%':
            continue
        consumed += 1
        result[(int(position) if position else consumed, kind)] += 1
    return result


def units(localization: dict) -> dict[str, str]:
    if set(localization) - {'stringUnit', 'variations'} or ('stringUnit' in localization and 'variations' in localization):
        raise ValueError('Unsupported catalog extraction pattern; extend the typed resource generator')
    if 'stringUnit' in localization:
        unit = localization['stringUnit']
        if not isinstance(unit.get('value'), str):
            raise ValueError('stringUnit.value must be text')
        return {'value': unit['value']}
    variants = localization.get('variations', {})
    if set(variants) != {'plural'}:
        raise ValueError('Expected a stringUnit or plural variations; unsupported variation cannot be skipped')
    return {form: units(item)['value'] for form, item in variants['plural'].items()}


def localized(value: dict[str, str]) -> dict:
    def unit(text):
        return {'stringUnit': {'state': 'translated', 'value': text}}
    return unit(value['value']) if set(value) == {'value'} else {
        'variations': {'plural': {form: unit(text) for form, text in sorted(value.items())}}}


def markup(text: str) -> Counter:
    # Semantic tokens survive translation and keep keyword/value identities out of prose parsing.
    return Counter(re.findall(r'</?(?:keyword|value)(?:\s+[^>]+)?>', text))


def semantic_values(text: str) -> dict:
    if '<' in re.sub(r'<(/?)(keyword|value)(?: id="[a-z0-9_]+")?>', '', text) or '>' in re.sub(r'<(/?)(keyword|value)(?: id="[a-z0-9_]+")?>', '', text):
        raise ValueError('Unsupported or damaged semantic markup')
    result = {}
    stack = []
    for token in re.finditer(r'<(/?)(keyword|value)(?: id="([a-z0-9_]+)")?>', text):
        closing, kind, identifier = token.groups()
        if closing:
            if not stack or stack[-1][0] != kind:
                raise ValueError('Unbalanced semantic markup')
            _, identity, start = stack.pop()
            if kind == 'value':
                if identity in result:
                    raise ValueError(f'Duplicate semantic value identity: {identity}')
                result[identity] = placeholders(text[start:token.start()])
        else:
            if not identifier or stack:
                raise ValueError('Semantic spans require identities and cannot nest')
            stack.append((kind, identifier, token.end()))
    if stack:
        raise ValueError('Unclosed semantic markup')
    return result


def validate_translation(source: dict[str, str], value: dict[str, str], locale: str, label: str, plural_forms=None) -> None:
    expected_forms = {'value'} if set(source) == {'value'} else set(plural_forms or PLURALS[locale])
    if set(value) != expected_forms:
        raise ValueError(f'{label}: expected forms {sorted(expected_forms)}, received {sorted(value)}')
    reference = source.get('other', next(iter(source.values())))
    for form, text in value.items():
        original = source.get(form, reference)
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f'{label}/{form}: empty translation')
        if placeholders(text) != placeholders(original):
            raise ValueError(f'{label}/{form}: placeholder types, positions, or occurrences changed')
        if markup(text) != markup(original):
            raise ValueError(f'{label}/{form}: semantic markup changed')
        if semantic_values(text) != semantic_values(original):
            raise ValueError(f'{label}/{form}: values moved between semantic identities')
        if text.count('**') % 2 or text.count('`') % 2:
            raise ValueError(f'{label}/{form}: unbalanced formatting')


def inventory(root: Path):
    config = load(root / 'Localization/config.json')
    if config.get('sourceLanguage', 'en') != 'en':
        raise ValueError('English must remain the source and fallback language')
    locales = config['locales']
    if not locales or len(locales) != len(set(locales)) or any(not re.fullmatch(r'[a-z]{2,3}(?:-[A-Za-z0-9]+)*', item) or item == 'en' for item in locales):
        raise ValueError('Configure unique non-English locale identifiers')
    for locale in locales:
        forms = config.get('pluralForms', {}).get(locale, PLURALS.get(locale))
        if not forms or 'other' not in forms or len(forms) != len(set(forms)) or set(forms) - {'zero', 'one', 'two', 'few', 'many', 'other'}:
            raise ValueError(f'{locale}: configure pluralForms with its CLDR categories, including other')
    glossary = load(root / 'Localization/glossary.json')
    if not config['catalogs'] or len(config['catalogs']) != len(set(config['catalogs'])):
        raise ValueError('Configure at least one unique String Catalog')
    catalogs, entries = {}, {}
    for name in config['catalogs']:
        catalog = load(contained(root, name))
        if name == config.get('contentCatalog'):
            from internal.localization_sources import content_catalog
            catalog = content_catalog(root, catalog)
        if name == config.get('metadataCatalog'):
            from internal.localization_store import store_catalog
            catalog = store_catalog(root, catalog)
        if catalog.get('sourceLanguage') != 'en' or catalog.get('version') != '1.0':
            raise ValueError(f'{name}: expected an English version 1.0 String Catalog')
        catalogs[name] = catalog
        symbols = [key.replace('.', '_') for key in catalog['strings']]
        if len(symbols) != len(set(symbols)):
            raise ValueError(f'{name}: keys collide after typed Swift symbol generation')
        for key, entry in sorted(catalog['strings'].items()):
            if entry.get('shouldTranslate') is False:
                continue
            if not re.fullmatch(r'[a-z][a-z0-9_.]*', key):
                raise ValueError(f'{name}: invalid stable key {key}')
            source = units(entry.get('localizations', {}).get('en', {}))
            if not entry.get('comment', '').strip():
                raise ValueError(f'{name}/{key}: translator context is required')
            text = '\n'.join(source.values())
            terms = {term: definition for term, definition in glossary.items()
                     if re.search(r'(?<!\w)' + re.escape(term) + r'(?!\w)', text, re.IGNORECASE)}
            identifier = name + '::' + key
            entries[identifier] = {'catalog': name, 'key': key, 'source': source,
                                   'comment': entry['comment'], 'glossary': terms}
            entries[identifier]['source_hash'] = digest(entries[identifier])
    return config, catalogs, entries


def string_units(localization: dict):
    if 'stringUnit' in localization:
        yield localization['stringUnit']
    else:
        for item in localization.get('variations', {}).get('plural', {}).values():
            yield from string_units(item)


def enforce_glossary(entry: dict, value: dict, locale: str, identifier: str) -> None:
    for term, definition in entry['glossary'].items():
        required = definition.get('translations', {}).get(locale)
        if required and definition.get('enforce', False) and not any(required.casefold() in text.casefold() for text in value.values()):
            raise ValueError(f'{identifier}/{locale}: missing required glossary term {required}')


def plan(root: Path) -> dict:
    config, catalogs, entries = inventory(root)
    receipt_path = root / 'Localization/reviews.json'
    receipts = load(receipt_path) if receipt_path.exists() else {}
    pending = []
    for locale in config['locales']:
        for identifier, entry in entries.items():
            record = catalogs[entry['catalog']]['strings'][entry['key']].get('localizations', {}).get(locale)
            previous = units(record) if record else None
            receipt = receipts.get(identifier, {}).get(locale, {})
            valid = receipt.get('source_hash') == entry['source_hash'] and receipt.get('translation_hash') == digest(previous)
            try:
                if record and any(unit.get('state') != 'translated' for unit in string_units(record)):
                    raise ValueError('Translation unit is not complete')
                enforce_glossary(entry, previous or {}, locale, identifier)
                validate_translation(entry['source'], previous or {}, locale, identifier, config.get('pluralForms', {}).get(locale))
            except ValueError:
                valid = False
            if not valid or not REVIEW_CHECKS <= set(receipt.get('checks', [])) or not receipt.get('review'):
                pending.append({'id': identifier, 'locale': locale, **entry, 'previous': previous,
                                'placeholder_contract': {form: [{'position': position, 'type': kind, 'occurrences': count}
                                    for (position, kind), count in sorted(placeholders(text).items())]
                                    for form, text in entry['source'].items()}})
    revision = digest({'entries': entries, 'config': config})
    return {'version': 1, 'source_revision': revision, 'required_review_checks': sorted(REVIEW_CHECKS), 'requests': pending}


def response_template(root: Path, queue: dict | None = None) -> dict:
    """Copy queue identity and locale forms without inventing translation or review evidence."""
    queue = plan(root) if queue is None else queue
    config = load(root / 'Localization/config.json')
    results = []
    for item in queue['requests']:
        forms = ['value'] if 'value' in item['source'] else sorted(
            config.get('pluralForms', {}).get(item['locale']) or PLURALS[item['locale']])
        results.append({
            'id': item['id'], 'locale': item['locale'], 'source_hash': item['source_hash'],
            'translation': dict.fromkeys(forms, ''),
            'context': {key: item[key] for key in ('source', 'comment', 'glossary', 'placeholder_contract', 'previous') if key in item},
            'required_review_checks': queue['required_review_checks'],
            'review': {'verdict': 'pending', 'checks': [], 'rationale': ''},
        })
    return {'version': queue['version'], 'source_revision': queue['source_revision'], 'translations': results}


def prepare(root: Path, resume: Path | None = None) -> Path:
    """Start a fresh queue, carrying matching drafts without inventing review."""
    queue = plan(root)
    parent = root / '.DerivedData/Localization'
    parent.mkdir(parents=True, exist_ok=True)
    response = response_template(root, queue)
    if resume is None:
        candidates = [path for path in parent.glob('queue-*/response.json')
                      if not path.is_symlink() and not path.parent.is_symlink()]
        resume = max(candidates, key=lambda path: path.stat().st_mtime_ns, default=None)
    if resume is not None:
        previous = load(resume)
        if previous.get('version') != 1:
            raise ValueError(f'{resume}: unsupported draft version')
        saved = {}
        for item in previous['translations']:
            identity = (item['id'], item['locale'])
            if identity in saved:
                raise ValueError(f'{resume}: duplicate translation {identity}')
            saved[identity] = item
        for item in response['translations']:
            old = saved.get((item['id'], item['locale']))
            if old is None or old.get('source_hash') != item['source_hash']:
                continue
            item['translation'] = deepcopy(old['translation'])
            review = old.get('review', {})
            if (review.get('verdict') == 'pass' and REVIEW_CHECKS <= set(review.get('checks', []))
                    and review.get('rationale', '').strip()
                    and review.get('translation_hash') == digest(item['translation'])):
                item['review'] = deepcopy(review)
    directory = Path(tempfile.mkdtemp(prefix='queue-', dir=parent))
    (directory / 'plan.json').write_bytes(encoded(queue))
    (directory / 'response.json').write_bytes(encoded(response))
    return directory


def record_review(root: Path, response_path: Path, rationale: str) -> None:
    """Record the caller's explicit completed review; never translate or infer approval."""
    if not rationale.strip():
        raise ValueError('A rationale describing the completed separate review is required')
    with transaction_lock(root):
        response = load(response_path)
        queue = plan(root)
        if response.get('version') != 1 or response.get('source_revision') != queue['source_revision']:
            raise ValueError('Source revision changed; prepare a fresh response and review it again')
        config, _, entries = inventory(root)
        seen = set()
        for result in response['translations']:
            identifier, locale = result['id'], result['locale']
            if (identifier, locale) in seen or identifier not in entries or locale not in config['locales']:
                raise ValueError(f'Unknown or duplicate translation: {identifier}/{locale}')
            seen.add((identifier, locale))
            entry = entries[identifier]
            if result.get('source_hash') != entry['source_hash']:
                raise ValueError(f'{identifier}/{locale}: stale source fingerprint')
            value = result['translation']
            validate_translation(entry['source'], value, locale, identifier, config.get('pluralForms', {}).get(locale))
            enforce_glossary(entry, value, locale, identifier)
            previous = result.get('review', {})
            if (previous.get('verdict') == 'pass' and REVIEW_CHECKS <= set(previous.get('checks', []))
                    and previous.get('rationale', '').strip() and previous.get('translation_hash') == digest(value)):
                continue
            result['review'] = {'verdict': 'pass', 'checks': sorted(REVIEW_CHECKS),
                                'rationale': rationale, 'translation_hash': digest(value)}
        replace_files({response_path: encoded(response)})


@contextmanager
def transaction_lock(root: Path):
    # This is task-worktree-local. It never takes the repository integration lock.
    directory = root / '.DerivedData/Localization'
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'apply.lock').open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def replace_files(updates: dict[Path, bytes]) -> None:
    previous = {path: path.read_bytes() if path.exists() else None for path in updates}
    staged = {}
    replaced = []
    try:
        for path, data in updates.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            handle, name = tempfile.mkstemp(prefix='.localization-', dir=path.parent)
            with os.fdopen(handle, 'wb') as stream:
                stream.write(data)
            staged[path] = Path(name)
        for path, temporary in staged.items():
            os.replace(temporary, path)
            replaced.append(path)
    except BaseException:
        # Validation happens before this function. Restore a failed filesystem transaction.
        for path in reversed(replaced):
            if previous[path] is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(previous[path])
        raise
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)


def apply(root: Path, response: dict) -> None:
    with transaction_lock(root):
        queue = plan(root)
        if response.get('version') != 1 or response.get('source_revision') != queue['source_revision']:
            raise ValueError('Source revision changed; create a fresh queue before applying translations')
        config, catalogs, entries = inventory(root)
        catalogs = deepcopy(catalogs)
        receipt_path = root / 'Localization/reviews.json'
        receipts = load(receipt_path) if receipt_path.exists() else {}
        seen = set()
        for result in response['translations']:
            identifier, locale = result['id'], result['locale']
            if (identifier, locale) in seen or identifier not in entries or locale not in config['locales']:
                raise ValueError(f'Unknown or duplicate translation: {identifier}/{locale}')
            seen.add((identifier, locale))
            entry = entries[identifier]
            if result.get('source_hash') != entry['source_hash']:
                raise ValueError(f'{identifier}/{locale}: stale source fingerprint')
            value = result['translation']
            validate_translation(entry['source'], value, locale, identifier, config.get('pluralForms', {}).get(locale))
            review = result['review']
            if review.get('verdict') != 'pass' or not REVIEW_CHECKS <= set(review.get('checks', [])) or not review.get('rationale', '').strip():
                raise ValueError(f'{identifier}/{locale}: a completed second-pass AI review is required')
            if review.get('translation_hash') != digest(value):
                raise ValueError(f'{identifier}/{locale}: translation changed after review; review it again')
            enforce_glossary(entry, value, locale, identifier)
            catalogs[entry['catalog']]['strings'][entry['key']].setdefault('localizations', {})[locale] = localized(value)
            receipts.setdefault(identifier, {})[locale] = {
                'source_hash': entry['source_hash'], 'translation_hash': digest(value),
                'checks': sorted(REVIEW_CHECKS), 'review': review['rationale'],
            }
        updates = {contained(root, name): encoded_catalog(catalog) for name, catalog in catalogs.items()}
        from internal.localization_resources import generated_resources
        updates.update(generated_resources(root, catalogs))
        updates[receipt_path] = encoded_reviews({key: value for key, value in receipts.items() if key in entries})
        if plan(root)['source_revision'] != queue['source_revision']:
            raise ValueError('Source changed during validation; no translations were applied')
        replace_files({path: data for path, data in updates.items() if not path.exists() or path.read_bytes() != data})
        print(f'Applied {len(seen)} reviewed translations.')


def check(root: Path, paths: list[str] | None = None) -> list[str]:
    config = load(root / 'Localization/config.json')
    selected = None
    source_paths = None
    if paths is not None:
        from internal.cli import validate_repo_paths
        paths = [(root / path).resolve().relative_to(root.resolve()).as_posix()
                 for path in validate_repo_paths(paths, root)]
        def matches(path, *patterns):
            return any(fnmatchcase(path, pattern) for pattern in patterns)
        shared = ('Localization/config.json', 'Localization/glossary.json', 'Localization/reviews.json',
                  'Scripts/localization.py', 'Scripts/internal/localization*.py', '.github/*', 'project.yml')
        known = ('Packages/', 'Trinket/', 'TrinketUITests/', 'Scripts/', 'Localization/',
                 'ContentManifest/', 'Docs/', 'ArtManifest/', 'MusicManifest/', 'SoundManifest/')
        if all(path.startswith(known) or path.endswith('.md') for path in paths) and not any(matches(path, *shared) for path in paths):
            selected = {name for name in config['catalogs'] if name in paths or any(
                path.startswith(str(Path(name).parent.parent) + '/Generated/') for path in paths)}
            content = ('ContentManifest/*', 'Localization/source-keys.json', 'Localization/legacy-content.json',
                       'Packages/TrinketContent/Sources/TrinketContent/*.swift',
                       'Packages/TrinketAppState/Sources/TrinketAppState/Play/*.swift',
                       'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift')
            if config.get('contentCatalog') and any(matches(path, *content) for path in paths):
                selected.add(config['contentCatalog'])
            if config.get('metadataCatalog') and any(matches(path, 'Localization/Store/*') for path in paths):
                selected.add(config['metadataCatalog'])
            scopes = {str(Path(name).parent.parent) for name in selected if not name.startswith('Localization/')}
            if any(name.startswith('Trinket/') for name in selected):
                scopes.add('Trinket/Features')
            source_paths = {(root / path).resolve() for path in paths if path.endswith('.swift')}
            source_paths.update(path.resolve() for scope in scopes for path in (root / scope).rglob('*.swift'))
    queue = plan(root) if selected is None or selected else {'requests': []}
    errors = [f"{item['catalog']}/{item['key']} [{item['locale']}]: missing, stale, invalid, or unreviewed translation"
              for item in queue['requests'] if selected is None or item['catalog'] in selected]
    receipt_path = root / 'Localization/reviews.json'
    if selected is None and receipt_path.exists() and receipt_path.read_bytes() != encoded_reviews(load(receipt_path)):
        errors.append('Localization/reviews.json: use canonical compact review records; localization.py apply normalizes the format')
    for name in config['catalogs']:
        if selected is not None and name not in selected:
            continue
        path = contained(root, name)
        if path.read_bytes() != encoded_catalog(load(path)):
            errors.append(f'{name}: use canonical compact locale records; localization.py apply normalizes the format')
    from internal.localization_resources import resource_errors
    errors.extend(resource_errors(root, catalogs=selected, paths=source_paths))
    return errors
