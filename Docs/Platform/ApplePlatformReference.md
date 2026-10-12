# Trinket Apple API choices

Official Apple sources remain authoritative. This file records Trinket's platform
adoption choices. Motion and materials procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md).
Chrome tokens: [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md).
Banned legacy APIs are enforced by `./Scripts/check-api-bans.sh`.

## Platform support

[PD-026](../Product/Decisions.md) establishes iOS 18 as the supported minimum.
Give the newest release primary design attention; an older deployment target must
not prevent adopting useful current APIs or native system behavior. Use small
`#available` checks where an older supported version
needs the existing behavior. Avoid parallel UI frameworks and speculative shims.
Apple recommends [supporting older versions while adopting new APIs](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/).

The deployment target is the **minimum** supported OS, not the SDK version or a
maximum OS. The authored values in `project.yml` and `Packages/*/Package.swift`
remain authoritative. Keep iOS 18 support when adopting newer SDKs; a new public
major does not automatically raise the minimum. Review support cost and critical
capabilities before explicitly changing the minimum, preserve saves, and explain
any changed requirement in player-facing release notes. iOS 26+ keeps native glass
and scroll-edge treatments; shared controls use native bordered styles and material
surfaces on iOS 18. The explicit minimum-OS lane in [Player coverage](PlayerCoverage.md)
owns older-runtime evidence.

Availability also applies to Swift standard-library conformances and concurrency
runtime features. Indexed rows follow the [ForEach guidance](../../.agents/skills/swiftui-specialist/references/foreach.md);
resource teardown follows [Core lifetime support](../../Packages/TrinketCore/README.md#resource-lifetime)
to preserve the iOS 18.0 minimum.

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

## Portrait device support

[PD-033](../Product/Decisions.md) owns the shared stacked game arrangements for
iPhone, Duo, and native iPad. `project.yml` is authoritative for device families
and orientations; regenerate through the managed build workflow after changes.

iOS 27.1 and later use the native SwiftUI scene root so display transitions,
window geometry, and framework safe areas reach the game directly. All four
orientations are declared for iPhone and iPad. Layout follows current container
geometry rather than device orientation or identity. Keep enemy-above-party
battle arrangements and vertically stacked hubs in compact and expanded windows.
The compact horizontal presentation retains tab icons and stacked hubs; native
system bars may move with the available space. Do not add device-specific panels.

Before iOS 27.1, `PortraitAppRoot` retains the upright portrait lock through its
first-party hosting controller. Forward public scene/display inputs into that
hosted root; copying the entire `EnvironmentValues` replaces hosting's internal
accessibility state and hides cold-launch controls. Apply blanket safe-area
ignoring only to the legacy representable. Native game content receives system
safe areas; full-bleed artwork owns any scoped background exception. Root
scroll-edge and appearance modifiers belong to the shared game content.

`UIRequiresFullScreen` retains legacy orientation compatibility; the system
ignores it starting with iOS 27.1, matching the native root. Maintain runtime
resizing evidence for this versioned opt-out under
[TN3192](https://developer.apple.com/documentation/technotes/tn3192-Migrating-your-app-from-the-deprecated-UIRequiresFullScreen-key).
Verify reachable controls, sheets, and retained battle state through compact,
expanded, and rotated sizes; an orientation declaration alone proves none of them.
Use live safe areas and measured insets instead of fixed tab-bar or inspector
clearances. Preserve prepared artwork and the shared interaction hierarchy.

## Apple skill references

Two repository skills incorporate Apple's Xcode guidance:

- [swiftui-specialist](../../.agents/skills/swiftui-specialist/SKILL.md): SwiftUI
  implementation, observation, environment, identity, animation, and localization.
- [swiftui-whats-new-27](../../.agents/skills/swiftui-whats-new-27/SKILL.md): SDK 27
  migration diagnostics, new APIs, and their availability.

The reference snapshot was exported from **Xcode 27.0, build 27A266a** and
incorporated on September 14, 2026. Entrypoints and implementation references
are adapted for Trinket: local guidance distinguishes useful defaults from hard
invariants and removes repetitive examples. These are maintained adaptations,
not verbatim Apple policy.
These are on-demand technical references, not additional product or workflow
policy. [Documentation precedence](../README.md#policy-precedence), this page's
platform choices, and the routed package contracts still apply. When a snapshot
conflicts with the selected SDK, verify its public declarations and current Apple
documentation before adopting a symbol or updating the reference.

When refreshing for a new Xcode build, export to a temporary directory, compare
only the two selected skills while preserving local adaptations, then
update the snapshot version here; do not export directly over `.agents/skills/`.
Validate skill frontmatter, local links, and the scoped documentation handoff.

## Design reference routing

Apple HIG and WWDC material informs the [apple-design skill](../../.agents/skills/apple-design/SKILL.md)
topic files (gestures, foundations, materials, writing, feedback); that skill
owns the Trinket application of each source. Revisit the relevant Apple source
when changing the behavior or adopting a new SDK; a reviewed date does not
certify runtime behavior.

Broader accessibility remains governed by PD-014. Native portrait iPad support
follows PD-033 and the [device contract](#portrait-device-support). macOS expansion,
controllers, and new account or AI features need a product use case; appearing on
Apple's design site does not add them to Trinket.
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

Trinket selects its Asset Library Icon Composer package in `ArtManifest/app-icon.tsv` and installs
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
