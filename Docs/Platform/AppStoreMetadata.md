# App Store submission draft

Use for the existing App Store Connect app **Trinket: Heroes & Companions**
(`6811284921`). These fields describe the current local-only beta. Review them
against the selected release build before submission, especially iCloud behavior.
Release prerequisites and commands remain in [Release.md](Release.md).

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

Explore the Campaign, climb Spires, venture deeper into the Labyrinth, and take on Contracts. Between adventures, build your Homestead to strengthen your party and gather resources.

FREE TO START

Play the first three Campaign chapters, the first three Labyrinth floors, and the first ten floors of every Spire. Contracts are unlimited. Equipment, Homestead, and the ability and talent progression of accessible characters are available in free play.

ONE FULL GAME PURCHASE

A permanent, one-time Full Game purchase unlocks the remaining content. Heroes, Companions, equipment, and upgrades are still earned through play. Future content released within Trinket is included; there is no promised update schedule.

PLAY WITHOUT AN ACCOUNT

No Trinket account is required. Play offline, with progress currently saved on your device.

## Keywords

rpg,turn based,cards,strategy,deck,heroes,companions,fantasy,adventure,dungeon,offline

## Review notes

Trinket does not require an in-app account or sign-in. The current build stores progress locally and supports offline gameplay. iCloud progress sync remains disabled in distributed builds.

To inspect the Full Game offer, open Options → Full Game. The non-consumable product identifier is com.ryanmcintire.Trinket.fullgame. It unlocks content access; recruitment, items, levels, and upgrades remain earned through gameplay. Options → Restore Purchases restores eligible verified ownership. Reset Game Progress does not remove Full Game ownership.

## Owner checks before submission

- Confirm ownership/licensing of all content; the App Review phone number is saved.
- Complete and review Apple's age-rating questionnaire against the actual visuals
  and gameplay; do not infer rights or content disclosures from the app's genre.
- Reconcile the App Privacy answers and these drafts with the shipped build.
- Add release-build screenshots and choose the matching build only after release
  verification. The currently prepared store version and beta build versions can
  differ until that selection.

## Full Game purchase draft

App Store Connect product `6811501717` uses the existing identifier
`com.ryanmcintire.Trinket.fullgame`. The draft is a non-consumable named **Full Game**,
with English description **Unlock all chapters and game modes permanently.** and a
US base price of **$4.99**. Creation/localization/pricing do not submit the product
for review. Family Sharing was enabled after explicit owner confirmation.
Availability is configured for the United States for the owner's internal test.
The review screenshot remains unfinished. Paid Apps Agreement activation is pending
the owner's bank account and W-9; live sandbox purchase and restore verification
remain outstanding. No app review was requested.

## Cloud-enabled beta copy

Prepared for the first cloud-enabled internal TestFlight update; do not use this
copy for the existing local-only build. Activation belongs to the
[CloudKit checklist](CloudKitPreShipChecklist.md#prepared-testflight-activation).

**What to Test:** Progress now syncs automatically between devices signed into the
same iCloud account. Play on one device, then reopen Trinket on the other. Check
Campaign progress, your party, equipment, and Homestead. Offline adventures remain
available; Homestead collection and upgrades need a connection while using iCloud.
Reset Game Progress applies across your synced devices, including a device that
reconnects later. This is a development beta; use test progress.

**Replacement account paragraph:** No Trinket account is required. With iCloud
signed in, progress syncs automatically across your devices. Play adventures offline
and reconnect to sync your progress. Homestead collection and upgrades require a
connection while using iCloud.

**Review-note replacement:** Trinket uses the device's iCloud account for automatic
progress sync and has no in-app login. Without iCloud, progress remains local.
Conflicting progress is resolved automatically using a complete save, with the
other save retained as a recovery backup. Reset Game Progress propagates to synced
devices and does not remove Full Game ownership.
