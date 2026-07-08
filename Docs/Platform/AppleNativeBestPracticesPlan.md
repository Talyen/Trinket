# Apple / Swift Native Best Practices Plan

Implementation plan to close the remaining Apple-native gaps identified in the July 2026 stack review. Complements [iOS26StackAudit.md](iOS26StackAudit.md) and [AppleNativeGuidelines.md](../Design/AppleNativeGuidelines.md).

**Status:** Plan only — execute as stacked PRs on `main` (or cloud-agent feature branches).

**Out of scope:** Toolbar background / Liquid Glass Phase 4 audit. Hidden toolbar chrome on Battle, Play map, and combatant detail is an intentional art-forward choice and is **not** scheduled for migration. Do not reintroduce that work in platform docs or follow-up PRs unless product explicitly asks.

---

## Goals

| Goal | Success criteria |
|------|------------------|
| Haptics respect Options | Every `.sensoryFeedback` site is gated by `options.hapticsEnabled`; unit + smoke cover toggle off |
| Preferences are SwiftUI-native | `OptionsStore` uses `AppStorage` / `@AppStorage`-compatible keys; no hand-rolled `UserDefaults` get/set for options |
| Dynamic Type for icons | Decorative/placeholder SF Symbols use `@ScaledMetric` or semantic styles — zero fixed `.font(.system(size:))` in feature views |
| iOS 26 scroll chrome | Tab bar minimize + journey `backgroundExtensionEffect` + dense-list `scrollEdgeEffectStyle` adopted where product-safe |
| Privacy + App Store readiness | `PrivacyInfo.xcprivacy` present; Info.plist / generated keys declare iCloud sync intent when CloudKit ships |
| CloudKit prep without account | Local SwiftData path remains default; entitlements/docs staged so enabling CloudKit is a config flip after Developer Program enrollment |
| Concurrency hygiene | `NotificationToken` documents `Concurrency-Safety:`; no undocumented `@unchecked Sendable` in production |
| Audio stays correct | Keep ambient `AVAudioPlayer` session; document as intentional (not a migration target) |

---

## CloudKit and Apple Developer Program

**Do you need an Apple Developer account to proceed?**

| Work | Needs paid Developer Program? |
|------|-------------------------------|
| Local SwiftData saves, in-memory tests, `-disable-cloud-sync` | **No** |
| Privacy manifest, Options/`AppStorage` migration, haptics, Dynamic Type, iOS 26 chrome APIs | **No** |
| Filling `Trinket.entitlements` with iCloud/CloudKit keys that match a real container | **Yes** — container ID is created in the Apple Developer portal |
| Device/Simulator sync against a real `iCloud.com…` container | **Yes** |
| TestFlight / App Store with iCloud sync | **Yes** |

**Recommendation:** Complete Phases A–E and F1 (local-only CloudKit *prep*) without an account. Leave production CloudKit **disabled by default** until you enroll, create container `iCloud.com.ryanmcintire.Trinket`, and finish [CloudKitPreShipChecklist.md](../Audits/CloudKitPreShipChecklist.md). Do not claim live sync in App Review notes until F2 is done.

Free Apple ID + Xcode can build/run on Simulator today. Paid membership (~$99/year) is required for CloudKit containers, capability provisioning, and distribution.

---

## Phase map

| Phase | Theme | Depends on | Risk |
|-------|-------|------------|------|
| **A** | Wire haptics → sensory feedback | — | Low |
| **B** | Migrate Options to `AppStorage` | — | Medium (persistence of prefs) |
| **C** | Dynamic Type for decorative icons | — | Low |
| **D** | Adopt iOS 26 tab/scroll chrome APIs | C optional | Medium (UI smoke) |
| **E** | Privacy manifest + Info.plist hygiene | — | Low |
| **F1** | CloudKit local prep (no account) | E | Low |
| **F2** | CloudKit enablement (after Developer Program) | F1 + account | High (sync) |
| **G** | Concurrency / Foundation polish | — | Low |
| **H** | Docs + audit refresh | A–G as landed | — |

Ship as **separate PRs** in order A → B → C → D → E → F1 → G → H; hold F2 until enrollment.

---

## Phase A — Gate sensory feedback on haptics setting

**Problem:** `OptionsStore.hapticsEnabled` is toggled in Options but never read. All `.sensoryFeedback` call sites fire unconditionally.

**Migrate:**

1. Add a small design-system or app helper, e.g. `.trinketSensoryFeedback(_:trigger:enabled:)` or pass `enabled: appState.options.hapticsEnabled` at each site.
2. Update every production call site:
   - `ActiveStageCard.swift`
   - `HomesteadView.swift`
   - `HomesteadDetailViews.swift`
   - `ItemSlotPickerView.swift`
   - `AbilityTierPickerSheet.swift`
3. Prefer reading from `@Environment(AppState.self)` (or inject `Bool`) so sheets without full environment still compile.

**Tests:**

- Unit: Options toggle persists; helper/modifier does not fire when `enabled == false` (if testable via trigger counter / store).
- Smoke: Options haptics off → interact with Homestead upgrade / stage node (no crash; behavior unchanged visually).

**Verify:**

```sh
./Scripts/test.sh unit OptionsStoreTests
./Scripts/test.sh smoke
```

---

## Phase B — Migrate Options to SwiftUI `AppStorage`

**Problem:** `OptionsStore` hand-rolls `UserDefaults` get/set for music, effects, haptics, appearance.

**Target pattern:**

- Keep `@Observable` `OptionsStore` as the orchestration façade used by `AppState` **or** collapse to `@AppStorage` properties on a thin store — pick one and migrate all call sites.
- Preferred: store properties backed by `AppStorage` / shared `UserDefaults` suite with the **same key strings** (`options.musicVolume`, etc.) so existing installs keep values.
- Remove duplicated `defaults.set` / `defaults.object` in `didSet` once `AppStorage` owns persistence.
- Keep `AppState+Bootstrap.clearResetStateDefaults` clearing the same keys (reset must still wipe options when product requires it — today reset copy says settings are kept; preserve that product rule).

**Do not migrate into SwiftData/CloudKit** unless product later requires synced settings across devices ([Architecture.md](../Architecture.md) intentionally keeps options local).

**Tests:**

- Round-trip: set volumes/appearance/haptics → new `OptionsStore` instance → values match.
- Launch-arg `-appearance` still overrides for UI tests (`AppEnvironment`).

**Verify:**

```sh
./Scripts/test.sh unit OptionsStoreTests
./Scripts/test.sh unit AppStateSessionPersistenceTests
./Scripts/test.sh ui Smoke* --no-build   # after build
```

---

## Phase C — Dynamic Type for decorative icons

**Problem:** Fixed `.font(.system(size:))` on placeholder/lock glyphs fails strict Dynamic Type audits.

**Migrate each site to `@ScaledMetric` (or design-system token):**

| File | Notes |
|------|-------|
| `EmptySlots.swift` | Lock / empty glyph |
| `CombatantArtwork.swift` | Placeholder icon size param |
| `AbilityCard.swift` | Placeholder |
| `EncounterArtwork.swift` | Map placeholder |
| `HomesteadDetailViews.swift` | Node artwork fallback |
| `BattleOutcomeComponents.swift` | Outcome symbol |
| `Modifiers.swift` (`LockedCardEffectModifier`) | Locked overlay |
| Any remaining `ChapterGate*` / gate card icons | Grep-confirm |

**Pattern:**

```swift
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 38
// ...
Image(systemName: "...")
    .font(.system(size: iconSize, weight: .semibold))
```

Or centralize in `TrinketDesignSystem` as `TrinketDesign.Metrics.scaledIcon(_:relativeTo:)` if repetition ≥ 3.

**Verify:**

```sh
./Scripts/check-ui-style.sh
./Scripts/test.sh smoke
```

Manual: Accessibility → Larger Accessibility Sizes; icons grow without clipping cards.

---

## Phase D — Adopt remaining iOS 26 SwiftUI chrome APIs

**In scope (product-safe):**

1. **`.tabBarMinimizeBehavior(.onScrollDown)`** on root `TabView` in `ContentView.swift`.
   - Verify Battle full-screen / modal flows still expose tabs when needed.
   - If Battle regresses, scope minimize to Play/Collection only via per-tab APIs if available; otherwise keep global and document exception.

2. **`.backgroundExtensionEffect()`** on `ChapterJourneyHero` (Play journey).
   - Evaluate against existing `scrollTransition` / `ignoresSafeArea`.
   - Keep Reduce Transparency / Reduce Motion paths intact.

3. **`.scrollEdgeEffectStyle(...)`** on dense scroll surfaces: Collection shelves, Search results, Inventory lists, Options `Form`.
   - Prefer automatic/system defaults first; tune only if legibility fails over artwork.

**Out of scope:** Changing `.toolbarBackgroundVisibility` / `.toolbarBackground` on Battle, Play map, combatant detail (see top of this doc).

**Verify:**

```sh
./Scripts/test.sh smoke
./Scripts/test.sh ui SmokePlayTests
./Scripts/test.sh ui SmokeCollectionTests
```

---

## Phase E — Privacy manifest and Info.plist hygiene

**Problem:** No `PrivacyInfo.xcprivacy`. `UIBackgroundModes: remote-notification` is set in `project.yml` while CloudKit entitlements are empty — inconsistent App Store story.

**Do:**

1. Add `Trinket/PrivacyInfo.xcprivacy` (or XcodeGen-managed resource) declaring:
   - Collected data types as required for **iCloud game progress** when sync is enabled (can start with “no tracking”; sync declaration when F2 lands).
   - Any Required Reason API usage if present (UserDefaults is generally fine; audit `FileTimestamp` / disk APIs used by save recovery).
2. Wire the file into `project.yml` resources so it ships in the app bundle.
3. Revisit `INFOPLIST_KEY_UIBackgroundModes: remote-notification`:
   - **Keep** only if SwiftData/CloudKit silent push is required for sync wakeups **and** F2 is imminent.
   - **Remove** until CloudKit is enabled if it would trigger App Review questions without a real push/CloudKit capability.
4. Ensure Options reset copy and privacy questionnaire stay consistent with local-only vs iCloud (see F1/F2).

**Verify:** Archive build includes privacy manifest; `ci-locally.sh` / `build.sh` succeed.

---

## Phase F1 — CloudKit prep without Developer Program

**Do now (no account):**

1. Keep runtime default: CloudKit **off** unless `-enable-cloud-sync` (already true on Simulator in `AppEnvironment`).
2. Document in `Trinket.entitlements` / `project.yml` a **commented or docs-only** target entitlement shape — do **not** commit invalid entitlement keys that break signing for local/team builds. Prefer a short section in this plan + checklist over a broken empty-vs-fake entitlements file.
3. Confirm SwiftData models remain CloudKit-compatible (optional relationships, defaults, no `@Attribute(.unique)`) — already required by [CloudKitPreShipChecklist.md](../Audits/CloudKitPreShipChecklist.md).
4. Add/adjust unit tests that always use `disableCloudSync: true` / in-memory containers (already the norm).
5. Soften user-facing copy that asserts iCloud deletion if sync is not actually provisioned (Options reset alert currently mentions iCloud). Gate copy on “cloud sync configured” or say “on this device” until F2.

**Do not:** Create fake container IDs, enable `cloudKitDatabase: .automatic` in production configs, or check off pre-ship items that require portal access.

---

## Phase F2 — CloudKit enablement (after Apple Developer enrollment)

**Requires:** Paid Apple Developer Program membership.

1. Create App ID + CloudKit container `iCloud.com.ryanmcintire.Trinket`.
2. Fill `Trinket/Trinket.entitlements` with iCloud / CloudKit keys matching the portal.
3. Enable CloudKit on the production `ModelConfiguration` path when `disableCloudSync == false`.
4. Execute [CloudKitPreShipChecklist.md](../Audits/CloudKitPreShipChecklist.md) end-to-end (two devices, offline, reset propagation).
5. Restore accurate iCloud wording in Options reset + privacy questionnaire.
6. Re-enable `remote-notification` background mode only if needed for sync.

---

## Phase G — Concurrency and Foundation polish

1. Add `// Concurrency-Safety: …` to `NotificationToken` (`@unchecked Sendable`) explaining single-owner RAII + main-queue observer usage.
2. Grep for other undocumented `@unchecked Sendable` / `nonisolated(unsafe)` in non-generated production code; document or eliminate.
3. Leave `UIApplication.didReceiveMemoryWarningNotification` bridge in `AppState` — acceptable UIKit platform hook; optional follow-up to prefer scene-phase memory warnings if a pure-SwiftUI API appears.
4. Leave Balance CLI `DispatchQueue.concurrentPerform` as tooling-only.
5. **Audio:** Keep `AVAudioPlayer` + `.ambient` / `.mixWithOthers`. Add a one-paragraph note in `Trinket/Audio/` README or Architecture that this is intentional for looping BGM (not an AudioEngine migration).

---

## Phase H — Documentation refresh

Update after code lands:

| Doc | Change |
|-----|--------|
| [iOS26StackAudit.md](iOS26StackAudit.md) | Mark A–E/G complete; remove toolbar Phase 4 gap; point here for remaining F2 |
| [LiquidGlassMigrationPlan.md](LiquidGlassMigrationPlan.md) | Already drops Phase 4; status = complete |
| [AppleNativeGuidelines.md](../Design/AppleNativeGuidelines.md) | Link this plan; note haptics + AppStorage patterns |
| [Architecture.md](../Architecture.md) | Options/`AppStorage`; CloudKit gated on Developer Program |
| [CloudKitPreShipChecklist.md](../Audits/CloudKitPreShipChecklist.md) | Split “prep without account” vs “portal required” |
| [Platform README](README.md) | Link this plan |

---

## Explicit non-goals

| Item | Reason |
|------|--------|
| Toolbar background visibility migration (old audit §6 / Liquid Glass Phase 4) | Product keeps art-forward hidden chrome |
| Rewriting persistence to `@Query` / `.modelContainer` in every view | Store façade is intentional; optional future spike only |
| StoreKit 2 / GameKit | No product surface yet — use modern APIs when added |
| Replacing `AVAudioPlayer` with AVAudioEngine | Ambient looping BGM is correctly categorized today |
| Migrating options into CloudKit | Local preferences by design |

---

## PR / verification strategy

| PR | Phases | Suggested title |
|----|--------|-----------------|
| 1 | A | `fix(options): gate sensory feedback on haptics setting` |
| 2 | B | `refactor(options): migrate OptionsStore to AppStorage` |
| 3 | C | `a11y(design): scale decorative icon fonts with Dynamic Type` |
| 4 | D | `feat(ui): adopt tabBarMinimize and scroll edge chrome APIs` |
| 5 | E + F1 | `chore(privacy): add PrivacyInfo; stage CloudKit-ready local defaults` |
| 6 | G + H | `docs(platform): concurrency notes + best-practices plan status` |
| later | F2 | `feat(sync): enable SwiftData CloudKit after Developer Program setup` |

**Per PR:**

```sh
./Scripts/check-ui-style.sh   # when UI/design touched
./Scripts/test.sh unit
./Scripts/test.sh smoke       # when UI touched
```

**Before merge of the full series:** `./Scripts/ci-locally.sh`

---

## References

- [iOS26StackAudit.md](iOS26StackAudit.md)
- [iOS26AppleReference.md](iOS26AppleReference.md)
- [LiquidGlassMigrationPlan.md](LiquidGlassMigrationPlan.md)
- [CloudKitPreShipChecklist.md](../Audits/CloudKitPreShipChecklist.md)
- [AppleNativeGuidelines.md](../Design/AppleNativeGuidelines.md)
- WWDC25-323 — tab minimize, background extension, scroll edge
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) — glass on controls; toolbar overrides intentionally retained for art screens
