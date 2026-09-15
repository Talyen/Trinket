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

Test new iOS/Xcode betas and release candidates before launch. Trinket always
adopts the newest installed Xcode for CI and local runs; `setup-trinket` selects
it automatically and records the exact version and build in its logs. Record
exact helper-tool versions for reproducibility in `Scripts/tool-versions.env`;
`SWIFT_VERSION` is language mode, not the compiler version, so do not update it
merely to match Xcode's bundled Swift compiler. Toolchain selection is
documented in [Scripts](../../Scripts/Reference.md#toolchain-ladder).

## Design reference routing

The September 14, 2026 review covered the design hub's main resource branches and
iPhone/game-relevant HIG and WWDC sections, not every recursive link in the video
archive or global site navigation. Revisit relevant sources when changing the
behavior or adopting a new SDK; a reviewed date does not certify runtime behavior.

| Apple source | Trinket application / owner |
|---|---|
| [Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games), [Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) | Touch reach, hit regions, and discoverable actions: [motion and gestures](../../.agents/skills/apple-design/motion-and-gestures.md) |
| [Brand identity on iOS](https://developer.apple.com/videos/play/wwdc2026/251/), [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles) | Native utility controls with distinctive fantasy content: [foundations](../../.agents/skills/apple-design/foundations-and-process.md) |
| [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views) | Material hierarchy and scroll edges: [materials and depth](../../.agents/skills/apple-design/materials-and-depth.md) |
| [Writing](https://developer.apple.com/design/human-interface-guidelines/writing), [Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help) | Labels, recovery copy, and contextual teaching: [writing and help](../../.agents/skills/apple-design/writing-and-help.md) |
| [Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio), [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) | Event meaning and device checks: [performance and feedback](../../.agents/skills/apple-design/performance-and-feedback.md) |
| [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | Semantic symbols and text roles: [visual roles](../../Packages/TrinketDesignSystem/Documentation/VisualRoles.md) |
| [Design with SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10115/), [Apple Design Resources](https://developer.apple.com/design/resources/) | Use shipping SwiftUI components in prototypes; official templates are optional references, not a second token system |
| [Design Awards](https://developer.apple.com/design/awards/), [Is This Seat Taken?](https://developer.apple.com/news/?id=z12xq8fa) | Inspiration for purposeful feedback and playtesting, not mandates to copy another game's systems |

Broader accessibility remains governed by PD-014. iPad/macOS expansion, controllers,
Wallet/Pass Designer, Reality Composer Pro, and new account or AI features need a
product use case; appearing on Apple's design site does not add them to Trinket.
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
