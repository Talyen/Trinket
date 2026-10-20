"""Repository-owned App Store copy and deterministic submission inputs (never uploads)."""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path


LIMITS = {'name': 30, 'subtitle': 30, 'promotionalText': 170, 'description': 4000,
          'keywords': 100, 'fullGameName': 30, 'fullGameDescription': 45}
STORE_LOCALES = {'en': 'en-US', 'ja': 'ja', 'ko': 'ko', 'de': 'de-DE', 'zh-Hant': 'zh-Hant', 'fr': 'fr-FR'}


def store_catalog(root: Path, previous: dict) -> dict:
    from internal.localization import load
    source = load(root / 'Localization/Store/English.json')
    if set(source) != set(LIMITS):
        raise ValueError('Store English copy must contain exactly: ' + ', '.join(LIMITS))
    strings = {}
    for key, value in source.items():
        if not isinstance(value, str) or not value.strip() or len(value) > LIMITS[key]:
            raise ValueError(f'Store English {key}: expected nonempty text of at most {LIMITS[key]} characters')
        entry = deepcopy(previous.get('strings', {}).get('store.' + key.lower(), {}))
        entry['comment'] = f'App Store {key}. Maximum {LIMITS[key]} characters. Trinket is the unchanged game brand; Full Game is the permanent, one-time non-consumable purchase. No subscriptions or paid random loot.'
        entry['extractionState'] = 'manual'
        entry.setdefault('localizations', {})['en'] = {'stringUnit': {'state': 'translated', 'value': value}}
        strings['store.' + key.lower()] = entry
    return {'sourceLanguage': 'en', 'version': '1.0', 'strings': strings}


def submission_files(root: Path, config: dict, catalog: dict) -> dict[Path, bytes]:
    from internal.localization import encoded, units
    output = {}
    for locale in ['en', *config['locales']]:
        fields = {}
        for key, limit in LIMITS.items():
            localization = catalog['strings']['store.' + key.lower()]['localizations'].get(locale)
            if localization is None:
                continue
            value = units(localization)
            if set(value) != {'value'} or not value['value'].strip() or len(value['value']) > limit:
                raise ValueError(f'App Store {locale}/{key}: expected nonempty text of at most {limit} characters')
            fields[key] = value['value']
        store_locales = config.get('storeLocales', {}).get(locale, STORE_LOCALES.get(locale))
        if isinstance(store_locales, str):
            store_locales = [store_locales]
        if not isinstance(store_locales, list) or not store_locales:
            raise ValueError(f'{locale}: configure App Store locales in storeLocales')
        for store_locale in store_locales:
            if not isinstance(store_locale, str) or not store_locale or '/' in store_locale or not all(part.isalnum() for part in store_locale.split('-')):
                raise ValueError(f'{locale}: configure a valid App Store locale in storeLocales')
            path = root / f'Localization/Generated/AppStore/{store_locale}.json'
            if path in output:
                raise ValueError(f'{locale}: duplicate App Store locale {store_locale}')
            output[path] = encoded(fields)
    return output
