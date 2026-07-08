# Apple-Native Reference Guide

Trinket-specific rules for applying Apple's 2026 platform APIs. The hard platform contract lives in `AGENTS.md` § Platform Baseline; official Apple documentation remains the source of truth for API shape.

**Trinket iOS 26 stack:** curated WWDC notes, API maps, codebase audit, and migration plans live in `Docs/Platform/` — start with [iOS26AppleReference.md](../Platform/iOS26AppleReference.md), [iOS26StackAudit.md](../Platform/iOS26StackAudit.md), [LiquidGlassMigrationPlan.md](../Platform/LiquidGlassMigrationPlan.md), and [AppleNativeBestPracticesPlan.md](../Platform/AppleNativeBestPracticesPlan.md).

## Platform Contract

| Requirement | Value |
|-------------|-------|
| Minimum OS | iOS 26.0 (`project.yml`) |
| Language | Swift 6.0 with strict concurrency |
| Toolchain | Xcode 26+ |
| UI | SwiftUI shell; UIKit only when SwiftUI has no viable API |

Do **not** add `#available` / `@available` checks for iOS versions below 26. We do not ship to older OSes. “Fallbacks” in Trinket design docs mean **accessibility** (Reduce Transparency, Reduce Motion), not backward compatibility.

## iOS 26 and Liquid Glass

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Build a SwiftUI app with the new design (WWDC25-323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/) — forward-looking APIs

## SwiftUI Patterns In This Repo

| Concern | API | Canonical example |
|---------|-----|-------------------|
| App state | `@Observable`, `@Environment`, `@Bindable` | `Trinket/State/AppState.swift`, `Trinket/App/ContentView.swift` |
| Navigation | `NavigationStack`, `navigationDestination`, sheets | `Trinket/Features/Collection/CollectionView.swift` |
| Tab shell | `TabView` + `Tab(..., value:)` | `Trinket/App/ContentView.swift` |
| Collection search | `.searchable` on Collection root | `Trinket/Features/Collection/CollectionView.swift` |
| Persistence | SwiftData `@Model`, `@Observable` stores | `Packages/TrinketPersistence/` |
| Chrome / surfaces | `TrinketDesign`, `.trinketSurface`, `.trinketMaterial` | `Packages/TrinketDesignSystem/` |
| Glass effects | `.glassEffect()` inside design system only | `VisualFoundation.swift` → `GlassChipModifier` |
| Haptics | `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate on `OptionsStore.hapticsEnabled` |
| Preferences | `OptionsStore` + `AppStorage` keys | `Trinket/State/OptionsStore.swift` |
| Materials + a11y | `MaterialRoleModifier` with Reduce Transparency fallback | `VisualFoundation.swift` |
| Typography | `.trinketTypography(_:)` semantic roles | `VisualFoundation.swift` → `TypographyRole` |
| Unit tests | Swift Testing (`@Suite`, `@Test`, `#expect`) | `TrinketTests/App/AppStateTests.swift` |
| UI tests | XCTest (`XCUIApplication`) | `TrinketUITests/Smoke/` |

When unsure, grep the repo for an existing pattern before inventing one.

## Deprecated Patterns — Do Not Use

| Avoid | Use instead | Why |
|-------|-------------|-----|
| `NavigationView` | `NavigationStack` | Deprecated navigation model |
| `ObservableObject` / `@StateObject` / `@Published` | `@Observable` / `@Environment` / `@Bindable` | Observation framework |
| `#available(iOS 18, *)` or similar | Nothing — deployment target is 26 | No backward compatibility |
| Raw `.buttonStyle(.glass)` in feature views | `.trinketGlassChip()` or design-system modifiers | Enforced by `check-ui-style.sh` |
| Raw `.background(.regularMaterial)` in feature views | `.trinketMaterial(_:)` | Enforced by `check-ui-style.sh` |
| `AnyView` | `@ViewBuilder` | Flagged by `check-ui-style.sh` |
| Custom UIKit wrappers | SwiftUI first | Portrait game shell |
| Hand-rolled colors in feature views | Semantic colors + `TrinketDesign` tokens | `AppVisualFoundation.md` |

## TrinketDesignSystem API Map

Route recurring chrome through `Packages/TrinketDesignSystem`. Feature views should call modifiers, not raw SwiftUI styling APIs.

| Modifier | Use for |
|----------|---------|
| `.trinketScreenBackground(_:)` | Tab/screen background by semantic mode |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled states |
| `.trinketMaterial(_:)` | Toolbars, sheets, popovers, reward reveals |
| `.trinketGlassChip()` | Glass capsule chips (iOS 26 `.glassEffect`) |
| `.trinketTypography(_:)` | Scalable text hierarchy |
| `.trinketCardSurface()` | 3:4 card identity tiles |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`) |

Bypass only with `// UIStyleCheck: allow - <reason>` or inside approved design-system files. See `Packages/TrinketDesignSystem/README.md` for the full API inventory.

## Accessibility

- Dynamic Type via semantic `TypographyRole` fonts.
- Reduce Transparency: materials and glass resolve to solid themed surfaces (`MaterialRoleModifier`, `GlassChipModifier`).
- Reduce Motion: replace movement-heavy battle feedback with fades and static glows (`AppVisualFoundation.md`).
- VoiceOver: `accessibilityIdentifier` on interactive controls; expose exact values for health, resources, and locked states.

## Apple Documentation Links

Use these for API shape and HIG intent — not for minimum OS version (Trinket targets iOS 26 only).

### Design And Platform

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games/)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion)
- [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)

### App Store And Privacy

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Submitting to the App Store](https://developer.apple.com/app-store/submitting/)
- [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)

### Frameworks

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI navigation](https://developer.apple.com/documentation/swiftui/navigation)
- [TabView](https://developer.apple.com/documentation/swiftui/tabview)
- [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Observation](https://developer.apple.com/documentation/observation)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [GameKit](https://developer.apple.com/documentation/gamekit)
- [StoreKit](https://developer.apple.com/documentation/storekit)
