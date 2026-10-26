# App Store submission draft

Submission fields for existing App Store Connect app `6811284921`. These are
candidate-dependent drafts, not a statement of live portal or distributed-build
state. Use local-only copy unless the named candidate has verified iCloud sync;
cloud-enabled replacements below require the
[activation gates](CloudKitPreShipChecklist.md#prepared-testflight-activation).
Product facts (identifier, pricing, Family Sharing) live in [Purchases.md](Purchases.md);
release prerequisites and commands remain in [Release.md](Release.md).

| Field | Draft |
|---|---|
| Subtitle | [Canonical English input](../../Localization/Store/English.json) |
| Primary category | Games |
| Games subcategories | Roleplaying; Strategy |
| Support URL | https://talyen.github.io/Trinket/ |
| Privacy policy URL | https://talyen.github.io/Trinket/privacy.html |
| Copyright | 2026 Ryan McIntire |
| Release method | Manual |
| Review sign-in required | No |
| Review contact | Ryan McIntire; rymcintire@gmail.com; phone supplied directly to App Store Connect |

## Localized submission fields

[Localization/Store/English.json](../../Localization/Store/English.json) owns the
canonical English app name, subtitle, promotional text, description, keywords and
Full Game product copy. Edit that input in the development task, then complete the
[agent translation workflow](Localization.md). Locale-specific, length-checked
submission files are generated under
[Localization/Generated/AppStore](../../Localization/Generated/AppStore/). Uploads
and publication remain in the authorized release process.

## Review notes

Trinket does not require an in-app account or sign-in. The current build stores progress locally and supports offline gameplay. iCloud progress sync remains disabled in distributed builds.

To review Full Game, open Options → Unlock Full Game. This one-time, non-consumable purchase unlocks the remaining chapters, modes, Heroes, and Companions; characters and upgrades are still earned through play. Options → Restore Purchases restores verified ownership, including eligible Family Sharing access. Options → Reset Game Progress clears gameplay progress but keeps Full Game ownership.

## Owner checks before submission

- Confirm ownership/licensing of all content; the App Review phone number is saved.
- Complete and review Apple's age-rating questionnaire against the actual visuals
  and gameplay; do not infer rights or content disclosures from the app's genre.
- Reconcile the App Privacy answers and these drafts with the shipped build,
  following the [release procedure](Release.md#prepare-while-the-beta-is-running)
  for pages and answers and [Purchases.md](Purchases.md) for purchase behavior.
- Add release-build screenshots and choose the matching build only after release
  verification. The currently prepared store version and beta build versions can
  differ until that selection.

## Full Game purchase draft

App Store Connect product `6811501717` uses the existing identifier from
[Purchases.md](Purchases.md), with English description owned by
`Localization/Store/English.json` (**Unlock every chapter and game mode forever.**).
Submit the first non-consumable with the app version; product configuration alone
does not submit it for review.

### Candidate evidence

Record portal checks, purchase/device outcomes and unresolved prerequisites in the
candidate's release handoff. Before submission, recheck the
[purchase prerequisites](Purchases.md#before-release), listing fields/screenshots,
matching version/build and storefront availability under [Release](Release.md).
A historical sandbox purchase does not establish current production agreements,
Family Sharing or CloudKit readiness.

The October 12, 2026 portal and build-24 inspection is preserved in Git at
`47087791fa5b7f5fcd4466e6a7483bb5ac03ee94:Docs/Platform/AppStoreMetadata.md`
and in the documentation-consolidation task's retained evidence. It is a dated
baseline, not qualification of the next candidate.

## Cloud-enabled beta copy

Prepared for the first cloud-enabled internal TestFlight update; do not use this
copy for the existing local-only build. Activation belongs to the
[CloudKit checklist](CloudKitPreShipChecklist.md#prepared-testflight-activation).

**What to Test:** Progress now syncs automatically between devices signed into the
same iCloud account. Play on one device, then reopen Trinket on the other. Check
Campaign progress, your party, equipment, and Homestead. Adventures, Homestead
collection, and upgrades remain available offline; reconnect to sync your progress.
Check that progress earned separately on both devices merges automatically.
Reset Game Progress applies across your synced devices, including a device that
reconnects later. This is a development beta; use test progress.

**Replacement account paragraph:** No Trinket account is required. With iCloud
signed in, progress syncs automatically across your devices. Play adventures,
collect Homestead production, and build or upgrade offline, then reconnect to
sync your progress.

**Replacement for the opening review-note paragraph:** Trinket uses the device's iCloud account for automatic
progress sync and has no in-app login. Without iCloud, progress remains local.
Independent earned progress merges automatically, with conflicting saves retained
as recovery backups. Reset Game Progress propagates to synced
devices and does not remove Full Game ownership. Keep the Full Game review-note
paragraph above for either build.

## Prepared cloud-enabled website copy

Keep the published support and privacy pages local-only until an iCloud-enabled
build is distributed. At that rollout, replace their saved-progress sections with
the copy below, update the privacy policy's date, and reconcile App Privacy answers
with the exact build. The purchase, diagnostics, support-message, and website
sections of the privacy policy remain applicable.

**Privacy policy — Your saved game:** Your progress, characters, equipment, and
preferences are stored on your device. When iCloud progress sync is enabled in
your build and you are signed in to iCloud, saved progress also syncs through
your private iCloud storage across devices using the same Apple Account. You can
keep playing offline; changes sync after you reconnect. No Trinket account is
required, and the developer does not operate a game-save server.

You can reset gameplay progress in Options. When linked to iCloud, the reset also
clears synced progress on your other devices when they reconnect. Resetting does
not remove Full Game ownership. Deleting the app removes local data but may leave
saved progress in iCloud; you can manage the app's iCloud data in your device's
settings.

**Support page — Saved progress:** Progress is stored on your device. When iCloud
progress sync is enabled in your build and you are signed in to iCloud, it syncs
automatically across devices using the same Apple Account. You can play offline;
changes sync after you reconnect. If progress has not appeared on another device,
check that both devices use the same iCloud account and have a connection, then
reopen the app. Options → Reset Game Progress clears progress on this device and,
when linked to iCloud, on synced devices when they reconnect. It does not remove
Full Game ownership. Deleting the app can remove local progress, so do not
reinstall as a first troubleshooting step.
