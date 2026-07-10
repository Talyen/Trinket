# iOS 26 Apple Reference (Trinket)

Curated Apple documentation, WWDC sessions, and release guidance for Trinket's iOS 26 / Swift 6 stack. Official Apple sources remain authoritative; this doc highlights what matters for our portrait SwiftUI game shell.

**Trinket baseline:** iOS 26.0 deployment target, Swift 6.0, `SWIFT_STRICT_CONCURRENCY: complete` (`project.yml`).

---

## Liquid Glass and the new design system

Liquid Glass is the adaptive material Apple introduced for controls and navigation in iOS 26. Standard SwiftUI components (tab bars, toolbars, sheets, buttons) pick it up automatically when built with the Xcode 26 SDK.

### Apple documentation

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) — start here; covers visual refresh, controls, navigation, toolbars, sheets, and accessibility
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) — `.glassEffect(_:in:)`, shapes, tinting, interactivity
- [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass) — sample project
- [View.glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) — group multiple glass elements; required for morphing and performance
- [GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle) / [GlassProminentButtonStyle](https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle)

### WWDC25 design sessions

| Session | Title | Trinket relevance |
|---------|-------|-------------------|
| [WWDC25-323](https://developer.apple.com/videos/play/wwdc2025/323/) | Build a SwiftUI app with the new design | TabView, toolbars, search, controls, custom `.glassEffect` |
| [WWDC25 design system](https://developer.apple.com/videos/play/wwdc2025/) | Get to know the new design system | Design principles behind Liquid Glass |

### Key APIs from WWDC25-323 (SwiftUI)

| API | Use in Trinket |
|-----|----------------|
| `.tabBarMinimizeBehavior(.onScrollDown)` | Deliberately omitted — tab bar stays fully expanded on scroll |
| `.tabViewBottomAccessory { }` | Optional: persistent mini-player or battle status above tab bar |
| `.backgroundExtensionEffect()` | Play journey hero art extending under navigation chrome — best-practices plan Phase D |
| `.toolbarBackgroundVisibility(.hidden)` | Retained on Battle / Play map / combatant detail for art-forward chrome (not scheduled for removal) |
| `ToolbarSpacer` | Group related toolbar actions (e.g. battle menus) |
| `.sharedBackgroundVisibility(.hidden)` | Separate avatar or status items from grouped toolbar chrome |
| `.badge()` | Notification or milestone indicators on toolbar items |
| `.scrollEdgeEffectStyle()` | Tune legibility on dense scroll surfaces (Collection, Inventory) — best-practices plan Phase D |
| `.buttonStyle(.glass)` / `.glassProminent` | Route through `TrinketDesignSystem` (see `check-ui-style.sh`) |
| `.glassEffectID(_:in:)` + `@Namespace` | Morphing transitions between related glass chips |

### Apple guidance that affects Trinket

From [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass):

1. **Let system chrome adopt glass automatically** where it does not fight art-forward screens — Trinket retains hidden toolbar backgrounds on Battle, Play map, and combatant detail by product choice.
2. **Use glass sparingly on custom controls** — limit `.glassEffect` to high-value functional elements (combat feedback chips, wallet pills), not every card surface.
3. **Respect accessibility** — Liquid Glass adapts to Reduce Transparency and Reduce Motion; keep solid fallbacks (already patterned in `GlassChipModifier`).
4. **Avoid stacking glass on glass** — do not layer multiple translucent materials.

Trinket's dense Collection / Inventory surfaces should stay on **solid themed surfaces** (`TrinketDesignSystem` / `VisualFoundation`); glass belongs on navigation chrome and selective overlays. Follow-up migrations: [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md).

---

## SwiftUI platform updates (iOS 26 baseline)

Trinket already targets iOS 26 only, so these are **current APIs**, not migration targets.

| Area | Modern API | Legacy (not in codebase) |
|------|------------|--------------------------|
| Navigation | `NavigationStack`, `NavigationLink` | `NavigationView` |
| State | `@Observable`, `@Environment(Type.self)`, `@Bindable` | `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` |
| Change handling | `.onChange(of:) { old, new in }` | Single-parameter `.onChange` |
| Tabs | `Tab(...)` + `TabView(selection:)` | `.tabItem` + `.tag` on roots |
| Sheets | `.sheet(item:)` preferred | `.sheet(isPresented:)` still valid for booleans |
| Materials | `.glassEffect` for custom chrome | Raw `.background(.thinMaterial)` on feature views |
| Buttons | `.buttonStyle(.glass)` via design system | Raw `.buttonStyle(.bordered)` outside `TrinketDesignSystem` |

### WWDC26 SwiftUI (forward-looking)

These ship in the 2027 SDK cycle; not required for Trinket's current iOS 26 target but worth tracking:

- [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)
- [What's new in SwiftUI (WWDC26-269)](https://developer.apple.com/videos/play/wwdc2026/269/) — Document API, toolbar overflow/minimize, lazy `@State` for classes, `AsyncImage` HTTP caching
- [WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)

---

## Swift 6 and concurrency

Trinket enables **Swift 6 strict concurrency** on all targets. Relevant Apple guidance:

- [Swift 6 migration](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/) — `@MainActor`, `Sendable`, actor isolation
- [What's new in Swift (WWDC26-262)](https://wwdcnotes.com/documentation/wwdc26-262-whats-new-in-swift/) — `@diagnose`, ownership improvements, `Subprocess` package

Project audit: [SwiftConcurrencyDataRaceAudit.md](../Audits/SwiftConcurrencyDataRaceAudit.md).

---

## Frameworks Trinket may adopt later

| Framework | iOS 26 status | Trinket today |
|-----------|---------------|---------------|
| **StoreKit 2** | StoreKit 1 (`SKPayment*`) is deprecated / removed in Xcode 26 SDK | Not implemented; use StoreKit 2 when adding IAP |
| **GameKit** | Current APIs | Not implemented |
| **Foundation Models** | On-device Apple Intelligence framework (iOS 26) | Not used; evaluate only if product needs on-device LLM |
| **SceneKit** | Deprecated in Xcode 26; migrate to RealityKit | Not used (2D SwiftUI battle presentation) |

### StoreKit 2 starting points (when needed)

- [StoreKit documentation](https://developer.apple.com/documentation/storekit)
- [Product](https://developer.apple.com/documentation/storekit/product)
- [Transaction](https://developer.apple.com/documentation/storekit/transaction)

---

## App Store and SDK requirements

As of **April 28, 2026**, App Store submissions require **Xcode 26** and an SDK for iOS 26 or later ([Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)).

Hard-removed APIs to avoid (none found in Trinket production code):

- `UIWebView` → `WKWebView`
- `NSURLConnection` → `URLSession`
- `ABAddressBook` → `Contacts` framework
- `SKPaymentTransaction` / `SKPaymentQueue` → StoreKit 2

---

## App icons (Liquid Glass era)

iOS 26 app icons use layered compositions with system-applied effects. When preparing for App Store:

- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
- [Apple Design Resources](https://developer.apple.com/design/resources/) — updated icon grids

---

## Trinket implementation map

| Concern | Owner | iOS 26 doc |
|---------|-------|------------|
| Custom glass / materials | `Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift` | [iOS26StackAudit.md](iOS26StackAudit.md) § Liquid Glass |
| Tab shell | `Trinket/App/ContentView.swift` | This doc § TabView APIs |
| Style guardrails | `Scripts/check-ui-style.sh` | Route `.glassEffect` / `.buttonStyle(.glass*)` through design system |
| Visual foundation rules | `Packages/TrinketDesignSystem` (`VisualFoundation.swift`) | Dense vs glass surfaces |
| Fluid motion / gesture feel | [Apple Design skill](../Skills/apple-design/SKILL.md) | Principles via SwiftUI / `TrinketMotion` |
| Concurrency | `project.yml`, `@MainActor` stores | Swift 6 migration guide |
