"""Deterministic localization inventory and optimistic, transactional agent result application."""
from __future__ import annotations

from collections import Counter
from contextlib import contextmanager
from copy import deepcopy
import fcntl
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
            enforce_glossary(entry, value, locale, identifier)
            catalogs[entry['catalog']]['strings'][entry['key']].setdefault('localizations', {})[locale] = localized(value)
            receipts.setdefault(identifier, {})[locale] = {
                'source_hash': entry['source_hash'], 'translation_hash': digest(value),
                'checks': sorted(REVIEW_CHECKS), 'review': review['rationale'],
            }
        updates = {contained(root, name): encoded(catalog) for name, catalog in catalogs.items()}
        from internal.localization_resources import generated_resources
        updates.update(generated_resources(root, catalogs))
        updates[receipt_path] = encoded_reviews({key: value for key, value in receipts.items() if key in entries})
        if plan(root)['source_revision'] != queue['source_revision']:
            raise ValueError('Source changed during validation; no translations were applied')
        replace_files({path: data for path, data in updates.items() if not path.exists() or path.read_bytes() != data})
        print(f'Applied {len(seen)} reviewed translations.')


def check(root: Path) -> list[str]:
    queue = plan(root)
    errors = [f"{item['catalog']}/{item['key']} [{item['locale']}]: missing, stale, invalid, or unreviewed translation"
              for item in queue['requests']]
    receipt_path = root / 'Localization/reviews.json'
    if receipt_path.exists() and receipt_path.read_bytes() != encoded_reviews(load(receipt_path)):
        errors.append('Localization/reviews.json: use canonical compact review records; localization.py apply normalizes the format')
    from internal.localization_resources import resource_errors
    errors.extend(resource_errors(root))
    return errors
