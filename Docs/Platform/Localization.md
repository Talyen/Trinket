# Localization

English is the source and fallback language. Japanese, Korean, German,
Traditional Chinese, French, Spanish, and Brazilian Portuguese ship as bundled
native String Catalogs for offline play. iOS owns per-app language selection.
There is no paid translation API, runtime translation service, or human translation requirement.

## Agent workflow

Every displayed-copy change completes localization in the same task:

1. Edit the canonical English catalog, content, or [store copy](../../Localization/Store/English.json), preserving stable keys.
2. Run `python3 Scripts/localization.py run`. It prepares/resumes the queue, dispatches translation and independent review to separate ephemeral Codex CLI sessions, collects their structured results, applies resources and validates the inventory. Both passes use the configured model with high reasoning; no model, authentication, or account setting is changed. The workers return data in read-only sessions; only the coordinator applies validated resources.
3. Commit English, catalogs, review fingerprints and generated resources together.

The explicit local runner uses the signed-in Codex CLI and its AI allowance. A failed
or interrupted pass preserves the response path and phase logs; rerun `run` or use
`run --resume <response.json>`. Matching completed translations and reviews survive;
changed values still need independent review. There are at most two AI passes per run,
each bounded by `--timeout` (default 1800 seconds). Missing CLI/authentication or
allowance leaves the task incomplete; hooks, builds and CI cannot invoke this runner.

For another available AI tool, `python3 Scripts/localization.py job` still prepares
`translate.md` and `review.md`. Give the latter to a separate high-reasoning reviewer,
then run its printed `finish <response.json> --rationale …` command after actual
review. This manual interface remains supported; it requires no export to a human.

The job contains English, game context, glossary, previous translations,
placeholders, source fingerprints and native plural forms. Review meaning and
mechanics (actors, targets, conditions, timing, quantities and chance), terminology,
markup/placeholders and grammar for every pending supplied entry. Correct defects
before attesting. Do not fabricate review records, copy English to clear the queue,
or drop configured languages. An unavailable AI allowance leaves an incomplete job.

`job` and `prepare` are aliases. A new job resumes matching drafts by default;
`--resume <response.json>` selects one explicitly. Original drafts are preserved.
Only matching source identities/hashes carry translations forward. Completed reviews
survive only when bound to the exact values; edited translations need review again.
Trim a batch to the entries actually reviewed when necessary. An incomplete batch
preserves applied work and exits nonzero with its remaining queue; resume the job.

`check` is the read-only gate. Legacy `review`/`apply`, stdout `plan`/`template`,
and manual review records remain compatible. Preparation never marks review complete;
`finish` performs no AI review; only the explicit local `run` coordinator dispatches AI passes. Hash-bound fingerprints prove recorded work, not
linguistic correctness. Hooks, builds and CI make no AI calls.

Swift-authored content uses stable source anchors. The initial key aliases in
`Localization/source-keys.json` preserve existing key identities; new anchors get
deterministic keys without English wording. If one shared source changes meaning,
the inventory reports the alias to split. Agents make that repository edit and
complete the resulting queue; no human translation/export step is required.

Source or glossary changes invalidate affected review records, including English
edits under unchanged keys. Applying old results fails. Run `prepare` again to
carry individually matching drafts and hash-bound reviews into the new revision;
translate/review changed entries. Unchanged applied translations are preserved.

`Localization/reviews.json` retains its nested JSON schema with one complete locale
review record per line. `apply` writes this deterministic compact format; `check`
rejects formatting drift. Hashes, completed checks, and full review rationales stay
intact. A current response with an empty `translations` array can normalize existing
records without translating again or creating new review evidence. String Catalogs
keep string keys and translator context expanded, with each complete locale record
on one line, including native plural forms. `apply` normalizes this JSON formatting;
`check` rejects formatting drift without changing translation or review data.

An unavailable AI allowance leaves a pending queue and an incomplete task. Do not
disable locales, bypass the gate, or mark English fallback as translated. Review
fingerprints record work performed; they do not establish linguistic correctness.

New languages use `locales`, `pluralForms` (CLDR categories), and `storeLocales`
in `Localization/config.json`. Run the same queue workflow, regenerate the project,
and add a matching CI screenshot case. No translation-provider integration is needed.

## Ownership and rendering

UI catalogs own their English wording. `L10n` typed accessors are generated by
`apply`; edit their catalogs, not generated Swift. Content manifests and authored
ability declarations remain canonical English inputs; their catalog inventory is
derived automatically. Spire positional titles/epithets and
Contracts/Voyage difficulty cases and computed encounter action titles have strict extractors that reject unsupported
source shapes. Generated `ContentCopy` keeps source identity separate
from displayed language, including canonical numeric text retained in older saves.
Its resource and description APIs share one match carrying the typed resource and
ordered quantities; descriptions bind those quantities to semantic value spans in
the rendering locale. Exact matches retain precedence over numeric templates.
`Localization/legacy-content.json` retains description templates still stored in
saved equipment after catalog wording changes. These localize the saved rule and
rolled quantities without adding newly authored bonuses to old powers.
Upgrade colors require matching keyword and quantity identities, independent of
word order, so expanded rules cannot compare unrelated saved stats.
Item names resolve by base identity through `InventoryItem.localizedDisplayName(locale:)`;
shared English words such as the weapon and attack “Maul” can require different translations.
Pass the app rendering locale into StoreKit product styles so storefront locale does
not replace the app language for authored purchase controls.

Use complete sentence templates, positional typed placeholders, native plurals,
and translator comments. Never assemble a translated sentence by joining English
fragments, force translated casing, or change raw enum/save/artwork identifiers.
Literal percent signs in catalog format strings use `%%`.

Resolve content arguments before passing them into a translated sentence; translating
“Build %1$@” or “%1$@, locked” does not translate the inserted building or character
name. Use the rendering environment's locale for both the content and its sentence.
For nested content names, declare the sentence's `resourceArguments` in
`Localization/config.json`, set the nested resource's locale, and use `Text(resource)`
for deferred SwiftUI sentence rendering. Generated String arguments otherwise
resolve content through the process locale before rendering. Do not pass an already
formatted sentence through `GameLabel` expecting its English fragments to translate.
Equipment search indexes the localized item noun, base type, displayed affixes, and
keyword names, using the same rendering locale for indexing and query normalization;
rebuild the index when that locale changes.

`LocalizedGameText` carries keyword IDs and named integer values through translated
word order. Preserve semantic tags and keep each placeholder inside its matching
value tag. Keyword highlighting and upgrade comparisons consume these identities,
not translated spellings or displayed number positions. Legacy rolled item text
is recognized only at the canonical English compatibility boundary, with typed
quantity bindings and native plurals. Resolve resources in the
rendering locale; retained English descriptions remain canonical data.

## Enforcement and release

Handoff and locked local integration run the read-only localization check through
the shared cheap-slice registry when source, catalog, or tooling inputs change.
The local `check --paths <files...>` validates selected Swift and affected catalogs,
generated resources and consumers. Shared config/glossary/review/tool changes
select full coverage; content inventory sources select their content catalog.
Unrelated translation queues do not block a source-only check. Documentation-only
tasks skip it locally. CI and unscoped `check` retain full coverage. Pre-push and
CI run the same check. They perform no AI calls, regeneration, compilation, or network requests. Translation and
generation run before taking the shared integration lock. The source check also
rejects direct `.name`, `.title`, `.description`, and `.rawValue` arguments (including
single-field string interpolation and multiline calls) to typed `L10n` templates.
This bounded check does not infer types or trace local variables/custom adapters;
`displayName` can already be localized by its presentation owner. Behavior tests
protect localized equipment search and index invalidation; those Swift tests run in CI.

Select local and hosted verification through the [confidence ladder](Verification.md#confidence-ladder).
Compiler extraction coverage, locale UI checks, and localized screenshots follow that policy.
`check-localization-build.py` reads compiler `.stringsdata` and compiled bundle
languages after the existing CI app build; it fails on missing extraction, unknown
keys, or absent languages. Pure numeric counters and punctuation separators need
no translation; text-bearing keys and string arguments remain inventoried.
`LocalizationUITests` in FullUI exercises earned Hero/Companion talent choices
and their return to Campaign, then captures battle cards,
ability details, progression, Options and Full Game for every configured language,
plus Apple’s double-length English pseudolocalization. The existing UI job exports
and retains the `*-localization-*` screenshot/hierarchy artifact automatically.
Inspect those images with the development agent before release;
fix clipping, script coverage, hidden actions, and unreadable rule text.

For a managed native text-size diagnostic, set the simulator through
`coverage_profiles.native_text_size`, which restores its previous setting.
`TEST_RUNNER_TRINKET_LOCALIZATION_LARGE_TEXT=1` makes these journeys verify that
the largest native setting reached SwiftUI, scroll the selected talent rules,
and require the unlock action to remain reachable. The flag asserts the setting;
it does not resize the app's text. Campaign screenshots also reject horizontal
overflow, Options checks scroll to controls in the lazy form, and Full Game checks
reach Restore Purchases while retaining the pinned purchase action. Review the
purchase screenshot itself to confirm the complete price is visible; an accessible
label alone does not establish that its rendered text fits.

### Pseudolanguage diagnostics

Compare suspected formatting defects with the same catalog entry in a real locale.
On Xcode 27.1 RC / iOS 26.5, Apple's `NSDoubleLocalizedStrings` changes the raw
bundle value `Quantity %1$lld` into `Quantity 1$lld Quantity %1$lld` before
interpolation. A Foundation-only `Bundle.localizedString(forKey:value:table:)`
probe reproduces this without game rendering. The first copy's format fragment is
a diagnostic artifact; keep placeholder validation and reviewed translations intact.

On the compact iPhone SE, native tab captions can overlap when this mode doubles
their titles. A custom SwiftUI tab `Label` with single-line fitting, tightening,
and a minimum scale factor produced the same rendered result on iOS 26.5. Retain
native tabs and the stress screenshots; judge shipping captions separately and
fix any overflow reproduced in a supported language. Do not suppress doubling or
change player-facing terminology just to make that diagnostic pass visually.
Apple also documents [custom pseudolocalizations](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/MaintaingYourOwnStringsFiles/MaintaingYourOwnStringsFiles.html)
when its built-in modes are insufficient; adopting one would be a separate test
tooling change, not a translation correction.

### Storefront preparation

Store metadata is generated under `Localization/Generated/AppStore/`, with field
length checks. Storefront copy and Full Game product copy are separate from the
binary's languages. Submission files and screenshots are preparation artifacts;
uploads, storefront changes, and publication follow the authorized release process.
Mainland China is deferred; Traditional Chinese initially targets Taiwan/Hong Kong.
Spanish uses broadly understandable game copy shared by the `es-ES` and `es-MX`
store metadata. `storeLocales` accepts a locale string or a list of storefront
locales sharing reviewed copy. Brazilian Portuguese uses `pt-BR` for both the game
and store metadata.


## References

Apple’s [agent localization workflow](https://developer.apple.com/documentation/xcode/localizing-your-app-using-agents)
explains agent-maintained String Catalogs. [Pseudolocalization testing](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html)
documents the language/region and double-length launch arguments used by CI.
Source catalogs are manually managed; compiler extraction is a read-only coverage
cross-check and cannot overwrite authored keys, English wording, or review evidence.

Project languages come from the configured catalogs and generated empty region
markers. XcodeGen reads the marker groups because it does not discover catalog
languages inside synchronized source folders. Adding a language also refreshes
the generated project through the existing project-generation workflow. The CI
bundle check requires compiled `Localizable` files, so a marker cannot masquerade
as a bundled translation.
