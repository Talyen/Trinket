# Trinket Apple API choices

Official Apple sources remain authoritative. This file records Trinket's platform
adoption choices. Motion and materials procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md).
Chrome tokens: [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md).
Banned legacy APIs are enforced by `./Scripts/check-api-bans.sh`.

## Platform support

[PD-026](../Product/Decisions.md) establishes a rolling window of the latest public
iOS major and its predecessor. Give the newest release primary design attention;
an older deployment target must not prevent adopting useful current APIs or native
system behavior. Use small `#available` checks where an older supported version
needs the existing behavior. Avoid parallel UI frameworks and speculative shims.
Apple recommends [supporting older versions while adopting new APIs](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/).

The deployment target is the **minimum** supported OS, not the SDK version or a
maximum OS. The authored values in `project.yml` and `Packages/*/Package.swift`
remain authoritative. Keep the current iOS 26 minimum through the iOS 27 transition;
this policy does not require backporting the game below its existing minimum.
Review the window at each public major release and advance the minimum in the
next verified app update, preserving saves and explaining the changed requirement
in player-facing release notes. Reconsider the window explicitly if support cost
or a critical capability warrants an exception.

Test new iOS/Xcode betas and release candidates before launch. [Toolchain selection](../../Scripts/Reference.md#toolchain-ladder)
owns which Xcode CI and local runs use, including version/build logging and helper-tool pins.
Trinket requires Swift 6.4 or newer (Xcode 27 or newer for Apple-platform builds).
Each `Package.swift` declares this minimum with `swift-tools-version: 6.4`;
`.swiftformat` targets the same syntax version. Packages use Swift 6 language mode
by default, and `project.yml` declares that mode with `SWIFT_VERSION: "6.0"`.
The values above mirror their executable owners (`project.yml`,
`Package.swift`, `.swiftformat`); change the owners,
not this page, and keep only the policy sentence here if they drift.
The language mode is distinct from the compiler and package tools versions:
`swiftc -swift-version` accepts `6`, not `6.4`. Do not change `SWIFT_VERSION`
merely to match Xcode's bundled Swift compiler.

## Apple skill references

Two repository skills incorporate Apple's Xcode guidance:

- [swiftui-specialist](../../.agents/skills/swiftui-specialist/SKILL.md): SwiftUI
  implementation, observation, environment, identity, animation, and localization.
- [swiftui-whats-new-27](../../.agents/skills/swiftui-whats-new-27/SKILL.md): SDK 27
  migration diagnostics, new APIs, and their availability.

The reference snapshot was exported from **Xcode 27.0, build 27A266a** and
incorporated on September 14, 2026, with entrypoints adapted for Trinket.
These are on-demand technical references, not additional product or workflow
policy. [Documentation precedence](../README.md#policy-precedence), this page's
platform choices, and the routed package contracts still apply. When a snapshot
conflicts with the selected SDK, verify its public declarations and current Apple
documentation before adopting a symbol or updating the reference.

When refreshing for a new Xcode build, export to a temporary directory, compare
only the two selected skills while preserving the adapted entrypoints, then
update the snapshot version here; do not export directly over `.agents/skills/`.
Validate skill frontmatter, local links, and the scoped documentation handoff.

## Design reference routing

Apple HIG and WWDC material informs the [apple-design skill](../../.agents/skills/apple-design/SKILL.md)
topic files (gestures, foundations, materials, writing, feedback); that skill
owns the Trinket application of each source. Revisit the relevant Apple source
when changing the behavior or adopting a new SDK; a reviewed date does not
certify runtime behavior.

Broader accessibility remains governed by PD-014. iPad/macOS expansion, controllers,
and new account or AI features need a product use case; appearing on Apple's
design site does not add them to Trinket.
New iOS APIs and symbols are evaluated for value and availability, not deferred
solely because they postdate the minimum supported OS.

## Liquid Glass

Start here: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass). Custom glass: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

| API | Trinket choice |
|-----|----------------|
| `.tabBarMinimizeBehavior(.onScrollDown)` | Omitted — tab bar stays fully expanded |
| `.toolbarBackgroundVisibility(.hidden)` | Retained on Battle / detail-hero screens |
| `.buttonStyle(.glass)` / `.glassProminent` | Route through `TrinketDesignSystem` (`check-ui-style.py`) |
| Raw `.glassEffect` in feature views | Forbidden — DesignSystem only |

Let system chrome adopt glass where it does not fight art-forward screens. Use glass sparingly through existing semantic components, such as compact resource chips. Dense Collection / Inventory / Options stay on solid themed surfaces. Floating combat feedback follows the [BattleFeature rendering contract](../../Packages/TrinketBattleFeature/README.md#uikit-feedback-island). Do not stack glass on glass. Accessibility: PD-014.

## Current vs banned SwiftUI

| Area | Use | Do not reintroduce |
|------|-----|-------------------|
| Navigation | `NavigationStack` | `NavigationView` |
| State | `@Observable`, `@Environment(Type.self)`, `@Bindable` | `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` |
| Change handling | two-parameter `onChange` | single-parameter `onChange` |
| Tabs | `Tab(...)` + `TabView(selection:)` | `.tabItem` + `.tag` on roots |

## Purchases and unused frameworks

Full Game uses StoreKit; [Purchases.md](Purchases.md) owns its development and
release workflow. New 3D work would use RealityKit, not SceneKit. GameKit and
Foundation Models are unused.

## App icon

Trinket authors the Icon Composer package under `Raw Assets/App Icon/` and installs
it as `Trinket/AppIcon.icon` via `Scripts/prepare-app-icon.sh`. Keep edits in the
authored package. [Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
owns the platform format; use the version compatible with the selected toolchain.

When changing the icon or adopting a new major OS, inspect recognition and clipping
at small Home Screen size across default, dark, clear, and tinted appearances
available on that OS. Preserve the same identifying silhouette across appearances;
let the system apply masking and material effects. Use the official
[app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)
and templates to assess safe composition. A layered package alone does not prove
every appearance works, and an illustrative icon does not automatically need to
be redrawn as a flat symbol.
