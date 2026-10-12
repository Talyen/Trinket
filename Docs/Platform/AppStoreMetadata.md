# App Store submission draft

Submission draft for App Store Connect app `6811284921`, currently named
**Trinket!**. The intended submission includes iCloud progress sync; current
published pages and the latest inspected beta remain local-only. Apply the
cloud-enabled replacements below only with a verified enabled build. These are
draft fields, not standing policy. Product facts (identifier, pricing, Family
Sharing) live in
[Purchases.md](Purchases.md); release prerequisites and commands remain in
[Release.md](Release.md).

| Field | Draft |
|---|---|
| Subtitle | Fantasy Card Battles |
| Primary category | Games |
| Games subcategories | Roleplaying; Strategy |
| Support URL | https://talyen.github.io/Trinket/ |
| Privacy policy URL | https://talyen.github.io/Trinket/privacy.html |
| Copyright | 2026 Ryan McIntire |
| Release method | Manual |
| Review sign-in required | No |
| Review contact | Ryan McIntire; rymcintire@gmail.com; phone supplied directly to App Store Connect |

## Promotional text

Build a party of Heroes and Companions, shape their abilities and equipment, and explore a fantasy world through turn-based card battles.

## Description

Pair a Hero with a Companion and guide them through turn-based card battles. Choose abilities, equip earned loot, unlock talents, and build a party that fits your strategy.

Explore the Campaign, climb Spires, venture deeper into the Labyrinth, take on Contracts, and embark on finite regional Voyages. Between adventures, build your Homestead to strengthen your party and gather resources.

FREE TO START

Play the first three Campaign chapters, the first three Labyrinth floors, and the first ten floors of every Spire. Contracts are unlimited, and Voyage includes Forest, Dungeon, and Desert adventures. Equipment, Homestead, and the ability and talent progression of accessible characters are available in free play.

ONE FULL GAME PURCHASE

A permanent, one-time Full Game purchase unlocks the remaining content. Heroes, Companions, equipment, and upgrades are still earned through play. Future content released within Trinket is included; there is no promised update schedule.

PLAY WITHOUT AN ACCOUNT

No Trinket account is required. Play offline, with progress currently saved on your device.

## Keywords

rpg,turn based,cards,strategy,deck,heroes,companions,fantasy,adventure,dungeon,offline

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
[Purchases.md](Purchases.md), with English description **Unlock all chapters and
game modes permanently.** Submit the first non-consumable with the app version;
product configuration alone does not submit it for review.

### Read-only readiness check — October 12, 2026

- Apple API: Full Game is a non-consumable in `MISSING_METADATA`, with Family
  Sharing enabled, US-only availability, and no purchase review screenshot or
  review note. English product localization is `PREPARE_FOR_SUBMISSION`.
- App version **1.0** is `PREPARE_FOR_SUBMISSION`, with manual release, no selected
  build, and no screenshot sets. Existing review contact fields are populated;
  sign-in is not required. The app name is **Trinket!**. The stored description
  and review notes still describe local-only progress and must be reconciled
  with the eventual cloud-enabled submission. The description also predates Voyage.
- Existing age-rating answers declare frequent/intense fantasy violence and
  weapons, mild/infrequent horror, and no paid loot boxes, gambling, chat, UGC,
  or advertising. These answers were read, not changed; a full release-artwork
  review and App Privacy answer reconciliation remain outstanding.
- iPhone 14 Pro, installed TestFlight **0.1.0 (24)**: live product loading showed
  **$4.99**; Apple's sheet explicitly stated testing only/no charge. A fresh
  purchase succeeded, the offer dismissed, and Options showed **Full Game ·
  Purchased**. Restore Purchases was exercised to completion and ownership
  remained; ownership also survived termination/relaunch. Existing Stage 1-8
  progress was preserved. This is not proof of fresh-install restoration,
  Family Sharing, refund handling, gameplay-reset behavior, or the changed UI.
- The retained local build-24 receipt records `cloud_sync=NO` and source
  `898ca7f19015a6f186a0ee2a5c02ffa02be31315`. It does not verify current cloud sync.
- Release doctor confirmed Apple API access and the existing Personal Testing
  internal group. Paid Apps Agreement/banking/tax status was not verified:
  the browser was signed out. Older pending-account notes are historical;
  sandbox purchase success does not establish production agreement status.

Before submission, verify the agreement directly, prepare and upload the
release-build purchase screenshot, add app screenshots, choose a matching
version/build, and confirm intended storefront availability. No portal fields,
website content, tester membership, uploads, or submission state were changed by
this check. The release candidate and current cloud-enabled device checks remain
pending under the [CloudKit checklist](CloudKitPreShipChecklist.md).

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
