# App Store submission draft

Data draft for the existing App Store Connect app **Trinket: Heroes & Companions**
(`6811284921`), not standing policy. These fields describe the current local-only
beta. Review them against the selected release build before submission, especially
iCloud behavior. Product facts (identifier, pricing, Family Sharing) live in
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
game modes permanently.** Creation/localization/pricing do not submit the product
for review. Availability is configured for the United States for the owner's
internal test. The review screenshot remains unfinished. Paid Apps Agreement,
banking/tax, and sandbox purchase/restore status follow
[Purchases.md](Purchases.md#before-release); current standing: agreement activation is pending
the owner's bank account and W-9, and live sandbox purchase and restore verification
remain outstanding. No app review was requested.

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
