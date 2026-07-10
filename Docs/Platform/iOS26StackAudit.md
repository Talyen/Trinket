# iOS 26 Stack Audit (Trinket)

Point-in-time audit: **July 2026**. Compares Trinket production code against iOS 16–25-era patterns and iOS 26 Apple guidance. See [iOS26AppleReference.md](iOS26AppleReference.md) for curated WWDC and documentation links.

**Verdict:** Trinket is on the modern Apple stack for state, navigation, concurrency, and tab structure. **Liquid Glass migration is complete** as of July 2026. **Apple-native best-practices Phases A–E, F1, G, H are implemented**; only **F2 (live CloudKit)** waits on Developer Program enrollment — see [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md).

**Implementation plans:** [LiquidGlassMigrationPlan.md](LiquidGlassMigrationPlan.md) (complete) · [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md)

---

## Summary

| Category | Status | Notes |
|----------|--------|-------|
| Deployment target | ✅ iOS 26.0 only | `project.yml`; no production `#available` gates |
| Swift language | ✅ Swift 6.0, strict concurrency | All package targets |
| Observation / state | ✅ `@Observable` throughout | Zero `ObservableObject` / `@Published` |
| Navigation | ✅ `NavigationStack` + modern `Tab` API | Zero `NavigationView` |
| `onChange` | ✅ Two-parameter form everywhere | 11 call sites |
| StoreKit / UIKit legacy | ✅ Clean | No `SKPayment*`, `UIWebView`, `UIScreen.main` |
| Liquid Glass | ✅ Complete | Shared `TrinketGlassBackgroundModifier`; badge/wallet/bottomBar glass; `GlassEffectContainer` on wallet row |
| Primary CTAs | ✅ `.glassProminent` | `PrimaryActionButtonModifier` migrated |
| UI test guard | ✅ Removed | `performAccessibilityAudit()` unconditional at iOS 26 |
| Toolbar backgrounds | ✅ Intentional | Hidden chrome retained on Battle / Play map / combatant detail for art-forward screens — not scheduled for change |
| Dynamic Type (icons) | ✅ `@ScaledMetric` | Decorative placeholder glyphs scale with content size |
| Haptics | ✅ Gated | `.trinketSensoryFeedback` respects Options toggle |
| Options prefs | ✅ `AppStorage` | `OptionsStore` uses AppStorage-backed keys |
| Privacy manifest | ✅ Present | `Trinket/PrivacyInfo.xcprivacy` (local-only; no tracking) |
| CloudKit | ⏸ F1 done | Local-only until Developer Program — see best-practices plan F2 |

---

## What is already modern (no action needed)

### State and data flow

All orchestration types use `@Observable` with `@MainActor` where required:

- `Trinket/State/AppState.swift`
- `Trinket/State/BattleSession.swift`
- `Trinket/State/OptionsStore.swift`
- `Packages/TrinketPersistence/` store types

Root injection uses `.environment(appState)` and `@Environment(AppState.self)` — not `@EnvironmentObject`.

### Navigation and tabs

```40:66:Trinket/App/ContentView.swift
        TabView(selection: selection) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                NavigationStack {
                    PlayView()
                }
            }
            // ... collection, homestead, options ...
        }
```

- Modern `Tab(...)` initializer (not legacy `.tabItem`)
- Product tabs only (Play / Collection / Homestead / Options)
- Per-tab `NavigationStack` (no `NavigationView`)

### Change observation

All `.onChange(of:)` call sites use the iOS 17+ two-parameter closure (`{ _, new in` or `{ old, new in`). No deprecated single-parameter form.

### Sheets and presentation

- **10** `.sheet(item:)` presentations (preferred identifiable pattern)
- **1** `.sheet(isPresented:)` — battle log toggle in `BattleView.swift` (acceptable for boolean state)
- `presentationDetents`, `presentationDragIndicator`, `safeAreaInset` in use

### Scroll and layout (iOS 17–18 APIs in active use)

- `scrollPosition(id:anchor:)` — Play map
- `scrollTargetLayout()` / `scrollTargetBehavior(.viewAligned)` — Collection shelves and search results
- `scrollTransition(.interactive)` — journey hero
- `ContentUnavailableView` — empty states
- `sensoryFeedback`, `symbolEffect`, `contentTransition(.numericText)`

### Concurrency

`SWIFT_STRICT_CONCURRENCY: complete` in `project.yml`. Battle tick loop and audio use structured `Task { @MainActor in }` patterns.

### Absent legacy APIs (verified by search)

| Legacy API | Found in production? |
|------------|-------------------|
| `NavigationView` | No |
| `@StateObject` / `@ObservedObject` / `@EnvironmentObject` | No |
| `ObservableObject` / `@Published` | No |
| `UIWebView`, `NSURLConnection`, `ABAddressBook` | No |
| `SKPayment*`, `SKProduct` (StoreKit 1) | No |
| `UIScreen.main` | No |
| `actionSheet` | No |
| `foregroundColor(` | No |

---

## Gaps and recommended improvements

### 1. Liquid Glass — design-system migration ✅ Complete (July 2026)

Implemented via `TrinketGlassBackgroundModifier` and updated `MaterialRoleStyle` role map. See git history on `VisualFoundation.swift`. Hidden toolbar backgrounds on Battle, Play map, and combatant detail are an intentional art-forward choice and are not scheduled for migration.

### 2. Tab bar minimize behavior — deliberately omitted

Product decision: do **not** use `.tabBarMinimizeBehavior(.onScrollDown)` on root `TabView`. Tab bar stays fully expanded.

### 3. Play journey `backgroundExtensionEffect` ✅ Complete

Applied on `ChapterJourneyHero`.

### 4. Stale UI test availability guard ✅ Complete

Guard removed; `performAccessibilityAudit()` runs unconditionally at iOS 26 deployment target.

### 5. Fixed decorative font sizes ✅ Complete

Decorative/placeholder SF Symbols use `@ScaledMetric` (best-practices plan Phase C).

### 6. Future framework adoption

When adding features, start with current APIs:

| Feature | Use | Avoid |
|---------|-----|-------|
| In-app purchase | StoreKit 2 (`Product`, `Transaction`) | StoreKit 1 |
| Leaderboards | Modern GameKit | Legacy GK APIs |
| 3D content | RealityKit | SceneKit (deprecated Xcode 26) |

Remaining CloudKit enablement (F2) is inventoried in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) and [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md). Phases A–E, F1, G are implemented.

---

## iOS 16–25 patterns explicitly not present

This audit searched for common migration targets. None remain in production Swift:

- **iOS 16:** `NavigationView`, `navigationBarTitle`, `foregroundColor`
- **iOS 17:** deprecated `onChange` (1-param), `inspector` workarounds
- **iOS 18:** legacy `Tab` `.tabItem` on root tabs
- **Pre-Swift 6:** `@Published` view models, completion-handler networking in UI layer

---

## Verification commands

After any Liquid Glass or chrome migration:

```sh
./Scripts/check-ui-style.sh
./Scripts/test.sh smoke
./Scripts/build.sh
```

Manual: launch with `-appearance light`, `-appearance dark`, and accessibility settings (Reduce Transparency, Reduce Motion) on iOS 26 simulator.

---

## Document maintenance

Re-run this audit when:

- Bumping deployment target or Xcode SDK
- Large `TrinketDesignSystem` visual changes
- Adding StoreKit, GameKit, or UIKit bridges
- After WWDC sessions that change SwiftUI chrome APIs

Update the "Point-in-time" date at the top when refreshed.
