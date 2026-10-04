---
type: execution-plan
status: active
created: 2026-09-29
updated: 2026-10-03
expires: 2026-10-13
---

# Rename the game to Fable & Fang

## Objective and scope

Use **Fable & Fang** everywhere players, testers, and App Review see the game's
name. Preserve **Trinket** as an equipment category and preserve the existing app,
purchase, and save identities. This is a plan and inventory; implementation and
publication have not begun.

Baseline: primary checkout on `main`, clean before this plan was created.
Inventory checked on 2026-09-29 through case-insensitive source, string-literal,
manifest, website, release-tooling, documentation, and asset-filename searches.
Generated project references were classified as internal rather than rename
inputs. No additional app-name literals were found in the other runtime Swift
files or authored content manifests. This establishes the repository inventory;
it does not establish the current contents of authenticated App Store Connect,
previously uploaded screenshots, or external marketing material.

## Confirmed external references

Line numbers below identify the baseline and may move during implementation.

| Surface | Owning input and baseline location | Planned change |
|---|---|---|
| Home Screen, App Library, and system app-name surfaces | [project.yml](../../project.yml), app target `info.properties`; [generated Info.plist](../../Trinket/Info.plist) currently has `CFBundleName = $(PRODUCT_NAME)` and no `CFBundleDisplayName` | Set `CFBundleDisplayName` and `CFBundleName` to `Fable & Fang` in the app target's authored `info.properties`. Keep `PRODUCT_NAME`, executable, target, and schemes unchanged; regenerate. Inspect the built plist and actual system presentation. |
| Animated loading title | [LaunchWarmupView.swift](../../Trinket/App/LaunchWarmupView.swift):41,44 | Change both the base text and masked accent overlay from `TRINKET` to `FABLE & FANG`. Both layers must have identical typography and geometry. |
| Loading accessibility name | Same file:55 | Change `Loading Trinket` to `Loading Fable & Fang`. |
| Startup recovery title | [TrinketApp.swift](../../Trinket/App/TrinketApp.swift):201, `AppBootstrapRecoveryView` | Change `TRINKET` to `FABLE & FANG`; verify the longer title fits with Retry and Support. |
| Support website | [Website/index.html](../../Website/index.html):6,7,12,15,21,24,25,27,29,31 | Replace every game-name occurrence in metadata, browser title, navigation, introduction, purchase/restore/Family Sharing/progress/refund copy. HTML uses `Fable &amp; Fang`. |
| Privacy website | [Website/privacy.html](../../Website/privacy.html):6,7,12,16,18,21,23,27,30,32 | Replace every game-name occurrence, including both mentions on lines 16 and 21, and the Support footer. Keep data-practice statements unchanged. HTML uses `Fable &amp; Fang`. |
| In-app external destinations | [FullGameOfferView.swift](../../Trinket/Features/Monetization/FullGameOfferView.swift):136–138, `TrinketPublicPages` | Privacy and Support URLs contain `/Trinket/`. Retain working URLs in the initial rename; see the URL decision below. The Swift enum name is internal. |
| App Store and beta copy draft | [AppStoreMetadata.md](../Platform/AppStoreMetadata.md):3,38,42,50,85,92,97 | Use `Fable & Fang`, replacing the recorded `Trinket: Heroes & Companions` title and game-name prose in the description, review notes, and prepared cloud-enabled beta copy. Add an explicit Name row. Keep local-only and cloud-enabled copy separate. |
| Default TestFlight What to Test text | [Scripts/internal/testflight.rb](../../Scripts/internal/testflight.rb):158 | Change the fallback `Trinket <version> (<build>)…` to `Fable & Fang…`. Explicit `--notes` files still need their own copy review. The READY message at line 333 is developer output and can remain. |
| Public GitHub release title | [.github/workflows/release.yml](../../.github/workflows/release.yml):117 | Change `Trinket ${{ github.ref_name }}` to `Fable & Fang ${{ github.ref_name }}`. Keep workflow identity, tags, release gates, and artifact paths unchanged. |
| Public repository introduction | [README.md](../../README.md):1; [cliff.toml](../../cliff.toml), `changelog.header` (generates the introduction in [CHANGELOG.md](../../CHANGELOG.md)) | Rename the README game heading and authored changelog header. Regenerate the changelog through the requested release workflow; do not hand-edit it. Preserve package links and existing release URLs. No title-brand references were found in current `ReleaseNotes/` text. |

The loading/recovery UI has **four game-name string literals**: three rendered
title layers and one accessibility label. No separate Options/About game-name
literal was found. StoreKit's localized purchase name is already **Full Game**;
its description has no old game title.

### Live website baseline and URL decision

Both [Support](https://talyen.github.io/Trinket/) and
[Privacy](https://talyen.github.io/Trinket/privacy.html) returned HTTP 200 on
2026-09-29, with titles `Trinket Support` and `Trinket Privacy Policy` respectively.
Their HTML contained 11 and 12 old-name occurrences. Local source agrees with
these counts. The initial web research tool could not open these pages; a direct
HTTP read verified them.

Recommended initial rollout: rename page content at the existing addresses.
The `/Trinket/` path is an existing public address, so it remains an explicit
legacy exception. This avoids inventing an undeployed destination and preserves
links embedded in installed builds. Publication uses the existing
[Support pages workflow](../../.github/workflows/pages.yml), triggered by a push
that includes website changes; a local edit alone is not a deployed rename.

If eliminating the old name from public URLs is also required, choose a branded
address separately, deploy it first, and keep the old pages serving or redirecting.
Then update `TrinketPublicPages`, the App Store draft's two URL rows, live App Store
Connect fields, and the URL guidance in [Release.md](../Platform/Release.md).
Renaming the repository is not required for the initial branding change.

### App Store Connect and uploaded media: inspection still required

The repository records app Apple ID **6811284921** and Full Game purchase Apple
ID **6811501717**. Confirm these against the current portal before editing.
Set the existing app's localized Name to **Fable & Fang**, check name availability,
and inspect every configured locale's description, promotional text, review
notes, TestFlight description/What to Test, support/privacy/marketing URLs,
screenshots, preview videos, custom product pages, and purchase review screenshot.
Replace old title text wherever present; retain valid equipment references.
These are checklist surfaces, not confirmed findings in the live portal.

The name is 12 characters, within Apple's 30-character limit. Name editing depends
on version status; Apple's [App information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
also states that the Bundle ID cannot change after a build is uploaded. Use the
existing app record, rather than creating a new identity for the rename.

## Documentation consistency

Update current prose naming the game, preserving literal paths, schemes, package
names, identifiers, and historical evidence. This secondary pass prevents future
release copy from reintroducing the old brand.

| Files | Current game-name references |
|---|---|
| [Release.md](../Platform/Release.md):3,58,149; [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md):3,29 | Game prose and recorded App Store Connect title/navigation. Update portal-name instructions when the live name changes. |
| [Purchases.md](../Platform/Purchases.md):18 | Game possessive in CloudKit prose; keep scheme names on lines 22–23. |
| [Monetization.md](../Product/Monetization.md):3,21; [Identity.md](../Product/Identity.md):3,17 | Game-name and account/purchase promise prose. |
| [Decisions.md](../Product/Decisions.md):20,28,32; [ArtworkStyleGuide.md](../Product/ArtworkStyleGuide.md):11 | Current product decisions and artwork prose. |
| [UniqueItems.md](../Product/UniqueItems.md):34 | `Trinket's combat rules` means the game. The Trinket catalogs/signatures on lines 7 and 33 mean equipment and stay. |
| [ApplePlatformReference.md](../Platform/ApplePlatformReference.md):1,3,28,50,68,74,82,108; [Testing.md](../Platform/Testing.md):3; [Architecture.md](../Platform/Architecture.md):3 | Current developer-facing game prose; optional cleanup in the same pass. Internal application/package/path names stay. |

Other agent guidance, package documentation, diagnostic instructions, archived
plans, and historical observations are developer surfaces. Do not turn this
rename into a whole-repository symbol or historical-record rewrite.

## Explicitly preserved references

- Equipment labels and rules: `Trinket`, `Secondary Trinket`, `Trinkets`,
  `Trinket Hoard`, `Better Trinket Odds`, `Drops a Trinket`, and item-card/detail
  `TRINKET` tags. Preserve `Polishing ancient trinkets…` in the loading terms.
- `ItemSlot` raw values, item/template IDs, catalogs, manifest fields, asset names,
  and `Raw Assets/Trinkets/`. These identify actual equipment or serialized data.
- Bundle ID `com.ryanmcintire.Trinket`, CloudKit container
  `iCloud.com.ryanmcintire.Trinket`, product ID
  `com.ryanmcintire.Trinket.fullgame`, record/zone/subscription identifiers,
  save filenames/keys, and `TrinketCloudEnvironment`/`TrinketCloudSyncEnabled`.
- Xcode project/target/scheme/product/executable names, `TrinketApp`, SPM package
  names/imports, source folders, test identifiers, `.storekit` filename,
  environment variables, logging/signpost subsystems, CI names, and local tooling
  configuration paths. `DesignSystemPreview`'s `Trinket Theme` is developer-only.
- Icon artwork: visually inspected the authored
  app icon image at `Raw Assets/App Icon/Trinket App Icon.jpg`;
  it contains a hero and wolf with no title text. Its hash matches the installed
  Icon Composer image. Keep the artwork and internal filenames. Asset-filename
  searches found no separate logo/title asset; uploaded media still needs review.

## Implementation sequence and acceptance

- [x] Inventory the local references, classify equipment/internal exceptions,
  verify the public website baseline, and inspect the app icon.
- [ ] Implement the app display metadata and four UI literals. Load the applicable
  SwiftUI/design skills and routed safeguards before editing. Preserve the launch
  artwork pins, loading timing, accent-fill animation, and recovery behavior.
- [ ] Update both website pages, App Store/beta drafts, the TestFlight fallback,
  public release title, README introduction, authored `cliff.toml` changelog header,
  and current product prose. Changelog output changes only through the requested
  release workflow under [Release.md](../Platform/Release.md#sources-of-truth).
- [ ] Regenerate through `./Scripts/generate.sh`; never hand-edit `Info.plist`,
  entitlements, Icon Composer installed output, or the Xcode project.
- [ ] Verify the built plist's display/name values and unchanged bundle, purchase,
  CloudKit, and product identities. Inspect Home Screen/App Library/system name,
  cold launch, and startup recovery on a narrow portrait device; check title fit,
  both overlay layers, and the loading accessibility label. Use the managed
  simulator skill for UI verification; retain stable accessibility identifiers.
- [ ] Check the two HTML pages' rendered/browser titles, copy, ampersand escaping,
  navigation, and links. Review residual case-insensitive old-name matches by
  category; no blanket search-and-replace or zero-match requirement.
- [ ] Add focused regression coverage only where consequential: inspect existing
  TestFlight notes tests and verify the changed fallback. Run path-scoped handoff
  for the complete changed-file set with `--isolate --quiet`, and `git diff --check`.
- [ ] When publication is requested, update the existing App Store Connect record
  and media, publish the website, and recheck live pages and links. Use the normal
  release/TestFlight procedure for a new build. Commit, push, upload, and portal
  writes are outside this planning request.
- [ ] After implementation and the agreed external rollout are complete, record
  the outcome in [Archived/README.md](Archived/README.md), delete this plan, and
  run the final handoff including the deleted plan path.

Completion means the installed game and current public copy use **Fable & Fang**,
Trinket items retain their names, existing progress and Full Game ownership retain
their identities, and any legacy URL or unverified external surface is explicitly
reported. No save migration, package rename, new app record, or replacement icon
is part of this plan.

## Planning handoff

The plan remains active for implementation. Validate this deliverable with
`./Scripts/handoff.sh --isolate --quiet --paths Docs/Plans/FableAndFangRename.md`
and `git diff --check`. App build/UI/purchase checks belong to implementation;
no runtime behavior was changed in this planning task.
