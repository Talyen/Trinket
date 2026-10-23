"""Protect translation freshness and application from silent mixed-language releases."""
from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
import tempfile
import unittest
from script_test_support import run_python

from internal.localization import apply, check, digest, encoded, encoded_catalog, plan, prepare, record_review, response_template, validate_translation


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.name = 'Packages/Example/Sources/Example/Resources/Localizable.xcstrings'
        self.write('Localization/config.json', {'locales': ['ja', 'de', 'fr'], 'catalogs': [self.name]})
        self.write('Localization/glossary.json', {'Burn': {'meaning': 'Damage each round', 'translations': {'ja': '炎上'}}})
        self.write('Localization/reviews.json', {})
        self.write(self.name, {'sourceLanguage': 'en', 'version': '1.0', 'strings': {
            'deal.burn': {'comment': 'Card rule; the number is damage to the enemy.',
                          'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': 'Deal %1$lld Burn damage'}}}},
        }})

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encoded(value))

    def response(self):
        queue = plan(self.root)
        text = {'ja': '%1$lldの炎上ダメージを与える', 'de': '%1$lld Brandschaden verursachen', 'fr': 'Inflige %1$lld dégâts de Brûlure'}
        return {'version': 1, 'source_revision': queue['source_revision'], 'translations': [
            {'id': item['id'], 'locale': item['locale'], 'source_hash': item['source_hash'],
             'translation': {'value': text[item['locale']]},
             'review': {'verdict': 'pass', 'checks': queue['required_review_checks'],
                        'rationale': 'Second pass checked the damage amount, enemy target, and Burn meaning.'}}
            for item in queue['requests']]}

    def test_prepare_review_apply_check_cli_journey(self):
        prefix = ['--root', str(self.root)]
        prepared = run_python('localization.py', *prefix, 'prepare', expected=0)
        response = Path(next(line.split(': ', 1)[1] for line in prepared.stdout.splitlines()
                             if line.startswith('Translate and separately review: ')))
        draft = json.loads(response.read_text())
        for item, translated in zip(draft['translations'], self.response()['translations']):
            item['translation'] = translated['translation']
        response.write_bytes(encoded(draft))
        run_python('localization.py', *prefix, 'review', str(response), '--rationale',
                   'Fixture separate review checked all required semantic and formatting dimensions.', expected=0)
        run_python('localization.py', *prefix, 'apply', str(response), expected=0)
        result = run_python('localization.py', *prefix, 'check', expected=0)
        self.assertIn('Localization PASS', result.stdout)

    def test_finish_requires_valid_translations_and_records_only_explicit_review(self):
        prefix = ['--root', str(self.root)]
        response = prepare(self.root) / 'response.json'
        pending = json.loads(response.read_text())
        run_python('localization.py', *prefix, 'finish', str(response), expected=2)
        run_python('localization.py', *prefix, 'finish', str(response),
                            '--rationale', 'Fixture separate review.', expected=2)
        self.assertEqual(json.loads(response.read_text()), pending)
        self.assertNotEqual(check(self.root), [])
        for item, translated in zip(pending['translations'], self.response()['translations']):
            item['translation'] = translated['translation']
        response.write_bytes(encoded(pending))
        run_python('localization.py', *prefix, 'finish', str(response), '--rationale',
                   'Fixture completed separate review of all required checks.', expected=0)
        self.assertEqual(check(self.root), [])
        # Later English changes cannot be attested or applied through an old draft.
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['localizations']['en']['stringUnit']['value'] = 'Take %1$lld Burn damage'
        self.write(self.name, catalog)
        run_python('localization.py', *prefix, 'finish', str(response), '--rationale',
                   'Fixture separate review.', expected=2)
        self.assertNotEqual(check(self.root), [])

    def test_same_key_english_edit_invalidates_every_translation(self):
        apply(self.root, self.response())
        self.assertEqual(check(self.root), [])
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['localizations']['en']['stringUnit']['value'] = 'Take %1$lld Burn damage'
        self.write(self.name, catalog)
        self.assertEqual({item['locale'] for item in plan(self.root)['requests']}, {'ja', 'de', 'fr'})

    def test_prepare_resumes_only_matching_sources_and_hash_bound_reviews(self):
        first = prepare(self.root)
        response = self.response()
        path = first / 'response.json'
        path.write_bytes(encoded(response))
        record_review(self.root, path, 'Separate review checked all required dimensions.')
        reviewed = json.loads(path.read_text())
        automatic = json.loads((prepare(self.root) / 'response.json').read_text())
        self.assertEqual(automatic['translations'][0]['review']['verdict'], 'pass')
        # A second entry changes the global revision but not the reviewed source.
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['another.rule'] = deepcopy(catalog['strings']['deal.burn'])
        self.write(self.name, catalog)
        resumed_path = prepare(self.root, path) / 'response.json'
        resumed = json.loads(resumed_path.read_text())
        old_id = self.name + '::deal.burn'
        for item in resumed['translations']:
            if item['id'] == old_id:
                self.assertEqual(item['review']['verdict'], 'pass')
                self.assertTrue(item['translation']['value'])
            else:
                self.assertEqual(item['review']['verdict'], 'pending')
                self.assertEqual(item['translation']['value'], '')
        translations = {item['locale']: item['translation'] for item in reviewed['translations']}
        for item in resumed['translations']:
            if item['review']['verdict'] == 'pending':
                item['translation'] = translations[item['locale']]
        resumed_path.write_bytes(encoded(resumed))
        record_review(self.root, resumed_path, 'Separate review of only the new rule.')
        resumed = json.loads(resumed_path.read_text())
        self.assertTrue(all(item['review']['rationale'] == 'Separate review checked all required dimensions.'
                            for item in resumed['translations'] if item['id'] == old_id))
        # Editing translated values never carries an old attestation forward.
        reviewed['translations'][0]['translation']['value'] += '.'
        path.write_bytes(encoded(reviewed))
        resumed = json.loads((prepare(self.root, path) / 'response.json').read_text())
        self.assertEqual(resumed['translations'][0]['review']['verdict'], 'pending')
        # Changed English invalidates the draft translation as well as its review.
        catalog['strings']['deal.burn']['localizations']['en']['stringUnit']['value'] = 'Take %1$lld Burn damage'
        self.write(self.name, catalog)
        resumed = json.loads((prepare(self.root, path) / 'response.json').read_text())
        for item in resumed['translations']:
            if item['id'] == old_id:
                self.assertEqual(item['translation']['value'], '')
                self.assertEqual(item['review']['verdict'], 'pending')

    def test_scoped_checks_ignore_unrelated_queue_but_validate_changed_sources_and_catalog_consumers(self):
        source = 'Packages/Example/Sources/Example/Screen.swift'
        path = self.root / source
        path.write_text('struct Screen {}\n')
        other = self.root / 'Packages/Other/Sources/Other/Screen.swift'
        other.parent.mkdir(parents=True)
        other.write_text('Text("Unrelated unlocalized copy")\n')
        self.assertTrue(check(self.root))  # This catalog still needs translation.
        self.assertEqual(check(self.root, [source]), [])
        hosted = run_python('localization.py', '--root', str(self.root), 'check', '--paths', source,
                            env={**os.environ, 'GITHUB_ACTIONS': 'true'}, expected=1)
        self.assertIn('missing, stale', hosted.stderr)
        self.assertTrue(check(self.root, ['unknown-input.config']))
        self.assertTrue(check(self.root, ['Localization/glossary.json']))
        self.assertTrue(any('unlocalized literal' in error for error in check(self.root, [str(other)])))
        path.write_text('Text("An untranslated action")\n')
        self.assertTrue(any('unlocalized literal' in error for error in check(self.root, [source])))
        path.write_text('Text(L10n.missing_key)\n')
        errors = check(self.root, [self.name])
        self.assertTrue(any('missing, stale' in error for error in errors))
        self.assertTrue(any('unknown typed localization resource' in error for error in errors))
        with self.assertRaises(ValueError):
            check(self.root, ['../outside.swift'])

    def test_apply_cli_validates_and_reports_incomplete_batches(self):
        response = self.response()
        response['translations'] = response['translations'][:1]
        path = self.root / 'response.json'
        path.write_bytes(encoded(response))
        result = run_python('localization.py', '--root', str(self.root), 'apply', str(path), expected=1)
        self.assertIn('localization remains incomplete', result.stderr)
        self.assertEqual(len(plan(self.root)['requests']), 2)

    def test_preparation_preserves_drafts_and_review_requires_valid_current_translations(self):
        first = prepare(self.root)
        draft = json.loads((first / 'response.json').read_text())
        self.assertEqual(draft['source_revision'], json.loads((first / 'plan.json').read_text())['source_revision'])
        self.assertIn('comment', draft['translations'][0]['context'])
        self.assertIn('glossary', draft['translations'][0]['context'])
        self.assertEqual(draft['translations'][0]['review']['verdict'], 'pending')
        before = (first / 'response.json').read_bytes()
        self.assertNotEqual(prepare(self.root), first)
        self.assertEqual((first / 'response.json').read_bytes(), before)
        with self.assertRaises(ValueError):
            record_review(self.root, first / 'response.json', 'Reviewed all five checks separately.')
        self.assertEqual((first / 'response.json').read_bytes(), before)
        self.assertEqual(json.loads((self.root / 'Localization/reviews.json').read_text()), {})

        response = self.response()
        for result in response['translations']:
            result['review'] = {'verdict': 'pending'}
        path = first / 'response.json'
        path.write_bytes(encoded(response))
        with self.assertRaises(ValueError):
            record_review(self.root, path, ' ')
        rationale = 'Separate review checked enemy damage, chance, glossary, grammar and placeholders.'
        record_review(self.root, path, rationale)
        reviewed = json.loads(path.read_text())
        changed = deepcopy(reviewed)
        changed['translations'][1]['translation']['value'] += '.'
        with self.assertRaisesRegex(ValueError, 'changed after review'):
            apply(self.root, changed)
        apply(self.root, reviewed)
        self.assertEqual(check(self.root), [])
        stale = deepcopy(reviewed)
        stale['source_revision'] = 'old'
        path.write_bytes(encoded(stale))
        with self.assertRaisesRegex(ValueError, 'revision changed'):
            record_review(self.root, path, rationale)

    def test_response_template_keeps_locale_forms_and_cannot_certify_unperformed_review(self):
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['localizations']['en'] = {'variations': {'plural': {
            form: {'stringUnit': {'state': 'translated', 'value': text}}
            for form, text in {'one': '%1$lld Burn', 'other': '%1$lld Burns'}.items()}}}
        self.write(self.name, catalog)
        queue = plan(self.root)
        draft = response_template(self.root)
        self.assertEqual(draft['source_revision'], queue['source_revision'])
        expected_forms = {'ja': {'other'}, 'de': {'one', 'other'}, 'fr': {'one', 'many', 'other'}}
        for item, request in zip(draft['translations'], queue['requests']):
            self.assertEqual(item['source_hash'], request['source_hash'])
            self.assertEqual(set(item['translation']), expected_forms[item['locale']])
            # Even fully populated translations cannot turn the template into review evidence.
            item['translation'] = {form: '%1$lld Burn' for form in item['translation']}
        before = (self.root / self.name).read_bytes()
        with self.assertRaisesRegex(ValueError, 'second-pass'):
            apply(self.root, draft)
        self.assertEqual((self.root / self.name).read_bytes(), before)

    def test_glossary_and_context_changes_invalidate_dependent_entries(self):
        apply(self.root, self.response())
        self.write('Localization/glossary.json', {'Burn': {'meaning': 'Fades rapidly each round', 'translations': {'ja': '炎上'}}})
        self.assertEqual(len(plan(self.root)['requests']), 3)
        apply(self.root, self.response())
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['comment'] = 'Self-inflicted damage, not enemy damage'
        self.write(self.name, catalog)
        self.assertEqual(len(plan(self.root)['requests']), 3)

    def test_invalid_batch_does_not_partially_update_catalogs_or_receipts(self):
        response = self.response()
        response['translations'][-1]['translation'] = {'value': 'Missing the damage placeholder'}
        before = {path.relative_to(self.root): path.read_bytes() for path in self.root.rglob('*.json')}
        catalog = (self.root / self.name).read_bytes()
        with self.assertRaisesRegex(ValueError, 'placeholder'):
            apply(self.root, response)
        self.assertEqual((self.root / self.name).read_bytes(), catalog)
        self.assertEqual(before, {path.relative_to(self.root): path.read_bytes() for path in self.root.rglob('*.json')})

    def test_concurrent_source_change_rejects_old_results(self):
        response = self.response()
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['comment'] += ' Updated context.'
        self.write(self.name, catalog)
        with self.assertRaisesRegex(ValueError, 'Source revision changed'):
            apply(self.root, response)

    def test_plural_forms_and_placeholder_types_are_checked(self):
        source = {'one': '%1$lld card', 'other': '%1$lld cards'}
        validate_translation(source, {'other': '%1$lld枚のカード'}, 'ja', 'cards')
        with self.assertRaisesRegex(ValueError, 'expected forms'):
            validate_translation(source, {'one': '%1$lld carte', 'other': '%1$lld cartes'}, 'fr', 'cards')
        with self.assertRaisesRegex(ValueError, 'placeholder'):
            validate_translation(source, {'one': '%1$@ Karte', 'other': '%1$@ Karten'}, 'de', 'cards')

    def test_review_and_translation_edits_cannot_silently_pass(self):
        response = self.response()
        response['translations'][0]['review']['checks'].remove('mechanics')
        with self.assertRaisesRegex(ValueError, 'second-pass'):
            apply(self.root, response)
        apply(self.root, self.response())
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['localizations']['ja']['stringUnit']['value'] = '自分が%1$lldの炎上ダメージを受ける'
        self.write(self.name, catalog)
        self.assertEqual([item['locale'] for item in plan(self.root)['requests']], ['ja'])

    def test_generation_is_idempotent_and_unchanged_translations_are_preserved(self):
        response = self.response()
        apply(self.root, response)
        before = {str(path): (path.read_bytes(), path.stat().st_mtime_ns) for path in self.root.rglob('*') if path.is_file() and '.DerivedData' not in path.parts}
        apply(self.root, response)
        self.assertEqual(before, {str(path): (path.read_bytes(), path.stat().st_mtime_ns) for path in self.root.rglob('*') if path.is_file() and '.DerivedData' not in path.parts})
        self.assertEqual(plan(self.root)['requests'], [])

    def test_compacting_legacy_receipts_preserves_all_evidence_and_other_files(self):
        apply(self.root, self.response())
        path = self.root / 'Localization/reviews.json'
        receipts = json.loads(path.read_text())
        record = next(iter(receipts.values()))['ja']
        record['review'] += '\nChecked Japanese: "炎上" and escaped \\ markup.'
        record['additional_evidence'] = {'notes': ['数量', 'actor and target'], 'passed': True}
        self.write('Localization/reviews.json', receipts)
        self.assertTrue(any('compact review records' in error for error in check(self.root)))
        before = {str(item): item.read_bytes() for item in self.root.rglob('*')
                  if item.is_file() and item != path and '.DerivedData' not in item.parts}
        queue = plan(self.root)
        self.assertEqual(queue['requests'], [])
        apply(self.root, {'version': 1, 'source_revision': queue['source_revision'], 'translations': []})
        self.assertEqual(json.loads(path.read_text()), receipts)
        lines = path.read_text().splitlines()
        records = [json.loads('{' + line.strip().rstrip(',') + '}') for line in lines if line.startswith('    ')]
        self.assertEqual(records, [{locale: record} for locales in receipts.values() for locale, record in sorted(locales.items())])
        self.assertEqual(before, {str(item): item.read_bytes() for item in self.root.rglob('*')
                                  if item.is_file() and item != path and '.DerivedData' not in item.parts})
        self.assertEqual(check(self.root), [])

    def test_compact_catalogs_preserve_plural_metadata_and_review_evidence(self):
        apply(self.root, self.response())
        path = self.root / self.name
        catalog = json.loads(path.read_text())
        catalog['metadata'] = {'notes': ['数量', 'Quoted "text"\nnext line', '\\'], 'enabled': True, 'optional': None}
        catalog['strings']['untranslated.plural'] = {
            'shouldTranslate': False,
            'localizations': {'en': {'variations': {'plural': {
                'one': {'stringUnit': {'state': 'translated', 'value': '%1$lld card'}},
                'other': {'stringUnit': {'state': 'translated', 'value': '%1$lld cards'}},
            }}}},
        }
        self.write(self.name, catalog)
        self.assertTrue(any('compact locale records' in error for error in check(self.root)))
        receipts = (self.root / 'Localization/reviews.json').read_bytes()
        queue = plan(self.root)
        self.assertEqual(queue['requests'], [])
        apply(self.root, {'version': 1, 'source_revision': queue['source_revision'], 'translations': []})
        self.assertEqual(json.loads(path.read_text()), catalog)
        self.assertEqual((self.root / 'Localization/reviews.json').read_bytes(), receipts)
        lines = {line.rstrip(',') for line in path.read_text().splitlines()}
        for locale, record in catalog['strings']['deal.burn']['localizations'].items():
            self.assertIn(f'        "{locale}": ' + json.dumps(record, ensure_ascii=False, sort_keys=True), lines)
        self.assertEqual(encoded_catalog(json.loads(path.read_bytes())), path.read_bytes())
        self.assertEqual(check(self.root), [])

    def test_semantic_token_identity_is_preserved_when_prose_reorders(self):
        source = {'value': '<keyword id="burn">Burn</keyword>: <value id="damage">%1$lld</value>'}
        validate_translation(source, {'value': '<value id="damage">%1$lld</value> <keyword id="burn">炎上</keyword>'}, 'ja', 'damage')
        with self.assertRaisesRegex(ValueError, 'semantic markup'):
            validate_translation(source, {'value': '<keyword id="health">体力</keyword>: <value id="damage">%1$lld</value>'}, 'ja', 'damage')

    def test_semantic_quantities_cannot_swap_even_when_printf_types_match(self):
        source = {'value': '<value id="damage">%1$lld</value> damage for <value id="turns">%2$lld</value> turns'}
        with self.assertRaisesRegex(ValueError, 'semantic identities'):
            validate_translation(source, {'value': '<value id="damage">%2$lld</value> Schaden für <value id="turns">%1$lld</value> Runden'}, 'de', 'rules')
        with self.assertRaisesRegex(ValueError, 'markup'):
            validate_translation({'value': 'Plain'}, {'value': '<script>Plain</script>'}, 'de', 'rules')

    def test_draft_states_and_required_glossary_terms_cannot_pass_read_only_check(self):
        apply(self.root, self.response())
        catalog = json.loads((self.root / self.name).read_text())
        catalog['strings']['deal.burn']['localizations']['ja']['stringUnit']['state'] = 'needs_review'
        self.write(self.name, catalog)
        self.assertEqual([item['locale'] for item in plan(self.root)['requests']], ['ja'])
        self.write('Localization/glossary.json', {'Burn': {'enforce': True, 'translations': {'de': 'Flammenschaden'}}})
        with self.assertRaisesRegex(ValueError, 'glossary term'):
            apply(self.root, self.response())

    def test_new_display_literals_and_unknown_typed_keys_are_actionable_failures(self):
        from internal.localization_sources import source_errors
        source = self.root / 'Packages/Example/Sources/Example/Screen.swift'
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text('Text("New untranslated button")\nMenu("New untranslated menu") {}\n.accessibilityAction(named: "New untranslated action") {}\nText(L10n.missing_key)\n')
        errors = source_errors(self.root)
        self.assertEqual(sum('unlocalized literal' in error for error in errors), 3)
        self.assertTrue(any('unknown typed localization resource' in error for error in errors))

    def test_canonical_content_arguments_cannot_hide_inside_translated_sentences(self):
        from internal.localization_sources import source_errors
        source = self.root / 'Packages/Example/Sources/Example/Screen.swift'
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text('''Text(L10n.deal_burn("\\(combatant.name)"))
Text(L10n.deal_burn(
    count,
    node.title
))
.accessibilityLabel(Text(L10n.deal_burn("\\(type.title)")))
Text(L10n.deal_burn(ContentCopy.localized(node.name, locale: locale)))
Text(L10n.deal_burn(item.localizedDisplayName(locale: locale)))
Text(L10n.deal_burn(category.displayName))
Text(verbatim: "L10n.deal_burn(node.title)")
Text(L10n.deal_burn("literal (punctuation), title", count))
// Text(L10n.deal_burn(combatant.name))
/* Text(L10n.deal_burn(node.description)) */
.accessibilityIdentifier("\\(combatant.name) card")
''')
        errors = [error for error in source_errors(self.root) if 'canonical content argument' in error]
        self.assertEqual(len(errors), 3)
        self.assertTrue(all('Screen.swift:' in error for error in errors))

    def test_swift_authored_keys_survive_english_edits(self):
        from internal.localization_sources import content_sources
        source = self.root / 'Packages/TrinketContent/Sources/TrinketContent/Fixture.swift'
        source.parent.mkdir(parents=True, exist_ok=True)
        keyword = self.root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift'
        keyword.parent.mkdir(parents=True, exist_ok=True)
        keyword.write_text('case burn = "Burn"')
        source.write_text('static let hero = Combatant(id: "hero", name: "First name")')
        first = content_sources(self.root)
        source.write_text('static let hero = Combatant(id: "hero", name: "Revised name")')
        revised = content_sources(self.root)
        self.assertEqual(set(first), set(revised))
        self.assertNotEqual(next(iter(first.values()))['text'], next(iter(revised.values()))['text'])

    def test_legacy_article_counts_become_typed_plural_templates(self):
        from internal.localization_sources import numeric_source, plural_sources
        text = 'Purge a buff when you deal Holy damage'
        self.assertEqual(numeric_source(text), 'Purge 1 buff when you deal Holy damage')
        self.assertEqual(plural_sources(text), {'one': 'Purge 1 buff when you deal Holy damage', 'other': 'Purge 1 buffs when you deal Holy damage'})
        self.assertEqual(plural_sources('Draw 2 cards')['one'], 'Draw 2 card')
        self.assertEqual(plural_sources('Gain 2 Block for 3 turns'), {'value': 'Gain 2 Block for 3 turns'})

    def test_additional_locale_uses_configured_plural_contract(self):
        config = json.loads((self.root / 'Localization/config.json').read_text())
        config['locales'] = ['es']
        config['pluralForms'] = {'es': ['one', 'many', 'other']}
        self.write('Localization/config.json', config)
        self.assertEqual(plan(self.root)['requests'][0]['locale'], 'es')
        validate_translation({'one': '%1$lld card', 'other': '%1$lld cards'},
                             {'one': '%1$lld carta', 'many': '%1$lld cartas', 'other': '%1$lld cartas'},
                             'es', 'cards', config['pluralForms']['es'])

    def test_store_limits_reject_overlong_translations(self):
        from internal.localization_store import LIMITS, submission_files
        catalog = {'strings': {'store.' + key.lower(): {'localizations': {'en': {'stringUnit': {'value': 'Valid'}}}} for key in LIMITS}}
        catalog['strings']['store.promotionaltext']['localizations']['fr'] = {'stringUnit': {'value': 'x' * 171}}
        with self.assertRaisesRegex(ValueError, 'fr/promotionalText'):
            submission_files(self.root, {'locales': ['fr']}, catalog)

    def test_shared_spanish_store_copy_covers_both_regions_without_overwriting_another_language(self):
        from internal.localization_store import LIMITS, submission_files
        catalog = {'strings': {'store.' + key.lower(): {'localizations': {
            locale: {'stringUnit': {'value': text}} for locale, text in [('en', 'English'), ('es', 'Español')]
        }} for key in LIMITS}}
        config = {'locales': ['es'], 'storeLocales': {'es': ['es-ES', 'es-MX']}}
        files = submission_files(self.root, config, catalog)
        directory = self.root / 'Localization/Generated/AppStore'
        self.assertEqual(set(files), {directory / f'{locale}.json' for locale in ['en-US', 'es-ES', 'es-MX']})
        for locale in ['es-ES', 'es-MX']:
            self.assertEqual(json.loads(files[directory / f'{locale}.json']), {key: 'Español' for key in LIMITS})
        self.assertEqual(json.loads(files[directory / 'en-US.json']), {key: 'English' for key in LIMITS})
        config['storeLocales']['es'].append('en-US')
        with self.assertRaisesRegex(ValueError, 'duplicate App Store locale en-US'):
            submission_files(self.root, config, catalog)

    def test_compiler_extraction_cross_check_rejects_uninventoried_keys_and_missing_languages(self):
        import importlib.util
        script = Path(__file__).resolve().parents[1] / 'check-localization-build.py'
        spec = importlib.util.spec_from_file_location('localization_build', script)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for key in ['%lld', '+%lld', '%lld/%lld', '·']:
            self.assertTrue(module.nonlinguistic_key(key))
        for key in ['Unregistered', '%lld damage', '%@']:
            self.assertFalse(module.nonlinguistic_key(key))
        derived = self.root / 'DerivedData'
        extracted = derived / 'Build/Intermediates.noindex/Screen.stringsdata'
        extracted.parent.mkdir(parents=True)
        extracted.write_bytes(encoded({'source': str(self.root / 'Packages/Example/Sources/Example/Screen.swift'), 'tables': {'Localizable': [{'key': key} for key in ['deal.burn', 'Unregistered', '%lld', '+%lld', '%lld/%lld', '·']]}}))
        app = self.root / 'Example.app'
        (app / 'Example_Example.bundle/en.lproj').mkdir(parents=True)
        errors = module.verify(self.root, derived, app)
        self.assertTrue(any('Unregistered' in error for error in errors))
        self.assertEqual(sum('unregistered display key' in error for error in errors), 1)
        self.assertTrue(any('missing bundled language ja' in error for error in errors))


if __name__ == '__main__':
    unittest.main()
