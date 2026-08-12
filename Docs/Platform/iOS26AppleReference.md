# Trinket Apple API choices

Official Apple sources remain authoritative. This file records **Trinket’s** forks of iOS 26 / Swift 6 APIs. Motion and materials procedure: [apple-design skill](../Skills/apple-design/SKILL.md). Chrome tokens: [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md). Banned legacy APIs are enforced by `./Scripts/check-platform-api-bans.sh`.

**Baseline:** iOS 26.0, Swift 6.0, `SWIFT_STRICT_CONCURRENCY: complete` (`project.yml`).

## Liquid Glass

Start here: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass). Custom glass: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

| API | Trinket choice |
|-----|----------------|
| `.tabBarMinimizeBehavior(.onScrollDown)` | Omitted — tab bar stays fully expanded |
| `.toolbarBackgroundVisibility(.hidden)` | Retained on Battle / detail-hero screens |
| `.buttonStyle(.glass)` / `.glassProminent` | Route through `TrinketDesignSystem` (`check-ui-style.sh`) |
| Raw `.glassEffect` in feature views | Forbidden — DesignSystem only |

Let system chrome adopt glass where it does not fight art-forward screens. Use glass sparingly on custom controls (combat chips, wallet pills), not every card. Dense Collection / Inventory / Options stay on solid themed surfaces. Do not stack glass on glass. Accessibility: PD-007.

## Current vs banned SwiftUI

| Area | Use | Do not reintroduce |
|------|-----|-------------------|
| Navigation | `NavigationStack` | `NavigationView` |
| State | `@Observable`, `@Environment(Type.self)`, `@Bindable` | `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` |
| Change handling | two-parameter `onChange` | single-parameter `onChange` |
| Tabs | `Tab(...)` + `TabView(selection:)` | `.tabItem` + `.tag` on roots |

## Later frameworks

When adding IAP, use StoreKit 2. New 3D work would use RealityKit, not SceneKit. GameKit and Foundation Models are unused.

## App icon

Trinket authors the Icon Composer package under `Raw Assets/App Icon/` and installs it as `Trinket/AppIcon.icon` via `Scripts/prepare-app-icon.sh`. Prefer the `.icon` package; iOS 26 consumes it directly. [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).
