# iOS 26 Stack Audit (Trinket)

Point-in-time audit: **July 2026**. Compares Trinket production code against iOS 16–25-era patterns and iOS 26 Apple guidance. See [iOS26AppleReference.md](iOS26AppleReference.md) for curated WWDC and documentation links.

**Verdict:** Trinket is already on the modern Apple stack for state, navigation, concurrency, and tab structure. The main gap is **partial Liquid Glass adoption** in `TrinketDesignSystem` and a few **low-priority polish items**.

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
| Liquid Glass | ⚠️ Partial | `GlassChipModifier` only; other modifiers still use `Material` |
| Primary CTAs | ⚠️ `.borderedProminent` | Consider `.glassProminent` via design system |
| UI test guard | ⚠️ Stale | `#available(iOS 17.0)` in accessibility audit helper |
| Dynamic Type (icons) | ⚠️ Minor | 7 files use fixed `.font(.system(size:))` for decorative glyphs |

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

```37:67:Trinket/App/ContentView.swift
        TabView(selection: selection) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                NavigationStack {
                    PlayView()
                }
            }
            // ... collection, homestead ...
            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView()
                }
            }
            // ...
        }
```

- Modern `Tab(...)` initializer (not legacy `.tabItem`)
- Search tab uses `role: .search` (WWDC25 bottom-search pattern)
- Per-tab `NavigationStack` (no `NavigationView`)

### Change observation

All `.onChange(of:)` call sites use the iOS 17+ two-parameter closure (`{ _, new in` or `{ old, new in`). No deprecated single-parameter form.

### Sheets and presentation

- **10** `.sheet(item:)` presentations (preferred identifiable pattern)
- **1** `.sheet(isPresented:)` — battle log toggle in `BattleView.swift` (acceptable for boolean state)
- `presentationDetents`, `presentationDragIndicator`, `safeAreaInset` in use

### Scroll and layout (iOS 17–18 APIs in active use)

- `scrollPosition(id:anchor:)` — Play map
- `scrollTargetLayout()` / `scrollTargetBehavior(.viewAligned)` — Collection shelves, Search
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

### 1. Liquid Glass — partial design-system migration (priority: medium)

**Current state** in `Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift`:

| Modifier | Material approach |
|----------|-------------------|
| `GlassChipModifier` | ✅ `.glassEffect(.regular)` + Reduce Transparency fallback |
| `StatusBadgeModifier` | ⚠️ `.background(.regularMaterial, ...)` |
| `WalletPillModifier` | ⚠️ `.background(.thinMaterial, ...)` |
| `MaterialRoleModifier` | ⚠️ `.thinMaterial` / `.regularMaterial` / `.ultraThinMaterial` |

Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) recommends `.glassEffect` and `.buttonStyle(.glass*)` for custom functional chrome, while **avoiding overuse** on content-heavy surfaces.

**Trinket policy** (from `AppVisualFoundation.md`):

- Glass: navigation chrome, combat feedback chips, wallet/status pills, modal headers
- Solid surfaces: Collection grids, Inventory rows, Search, Options forms

**Suggested rollout:**

1. Migrate `StatusBadgeModifier` and `WalletPillModifier` to `.glassEffect` (mirror `GlassChipModifier` fallback pattern).
2. Evaluate `MaterialRoleModifier` toolbar/bottom-bar roles — system tab/toolbar chrome may already provide glass; custom `.toolbarBackgroundVisibility(.hidden)` sites should be audited for scroll-edge conflicts.
3. Update `PrimaryActionButtonModifier` in `Modifiers.swift` from `.borderedProminent` to `.glassProminent` when design review approves.
4. Group related glass chips in `GlassEffectContainer` where multiple badges appear together (Homestead wallet row).

`Scripts/check-ui-style.sh` already restricts raw `.glassEffect` / `.buttonStyle(.glass*)` to `TrinketDesignSystem` — extend modifiers there, not in feature views.

### 2. Tab bar minimize behavior (priority: low, product decision)

iOS 26 floating tab bars support `.tabBarMinimizeBehavior(.onScrollDown)` ([WWDC25-323](https://developer.apple.com/videos/play/wwdc2025/323/)). Trinket does not opt in today.

**Consider for:** Play map (`ChapterStageSelectView`), long Collection shelves.

**Caution:** Battle and modal flows need predictable tab access; test smoke UI after enabling.

### 3. Play journey `backgroundExtensionEffect` (priority: low)

WWDC25 demonstrates hero art extending under sidebars via `.backgroundExtensionEffect()`. Trinket's chapter journey hero (`ChapterJourneyHero`) could adopt this for edge-to-edge presentation without clipping — evaluate against current `scrollTransition` treatment.

### 4. Stale UI test availability guard (priority: low)

```155:155:TrinketUITests/Support/TrinketUITestCase.swift
        guard #available(iOS 17.0, *) else { return }
```

Deployment target is iOS 26.0; this guard is dead code. Remove and call `performAccessibilityAudit()` unconditionally.

### 5. Fixed decorative font sizes (priority: low)

Seven files use `.font(.system(size: ...))` for placeholder/lock icons. These are not body text but may fail strict Dynamic Type audits. Consider `@ScaledMetric` or semantic icon styles where VoiceOver + Large Content Size matter.

Files: `EmptySlots.swift`, `CombatantArtwork.swift`, `AbilityCard.swift`, `EncounterArtwork.swift`, `ChapterGateCardView.swift`, `HomesteadDetailViews.swift`, `BattleOutcomeComponents.swift`, plus `Modifiers.swift` (locked card overlay).

### 6. Toolbar background hiding (priority: review)

Hidden toolbar backgrounds in Battle and Play may interfere with iOS 26's automatic scroll-edge effect ([Adopting Liquid Glass § Toolbars](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)):

- `BattleView.swift` — conditional `.toolbarBackgroundVisibility`
- `ChapterStageSelectView.swift` — `.toolbarBackgroundVisibility(.hidden)`
- `CombatantDetailPane.swift` — `.toolbarBackground(.hidden)` + visibility hidden

**Action:** Visual QA on iOS 26 simulator — confirm legibility over scrolling art. Remove redundant custom scrims if the system effect suffices.

### 7. Future framework adoption

When adding features, start with current APIs:

| Feature | Use | Avoid |
|---------|-----|-------|
| In-app purchase | StoreKit 2 (`Product`, `Transaction`) | StoreKit 1 |
| Leaderboards | Modern GameKit | Legacy GK APIs |
| 3D content | RealityKit | SceneKit (deprecated Xcode 26) |

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
