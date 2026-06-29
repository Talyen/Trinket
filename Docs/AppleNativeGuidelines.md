# Apple-Native Guidelines For Trinket

This document translates Apple's design, platform, App Store, and Swift guidance into working rules for Trinket. Treat the official Apple pages as the source of truth and this file as our project-specific operating checklist.

## Primary References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games/)
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion)
- [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Submitting to the App Store](https://developer.apple.com/app-store/submitting/)
- [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI navigation](https://developer.apple.com/documentation/swiftui/navigation)
- [TabView](https://developer.apple.com/documentation/swiftui/tabview)
- [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [GameKit](https://developer.apple.com/documentation/gamekit)
- [StoreKit](https://developer.apple.com/documentation/storekit)

## Design Principles

- Prefer Apple system patterns before custom game chrome: SwiftUI controls, native tab bars, sheets, alerts, menus, haptics, SF Symbols, system materials, and platform typography.
- Preserve a clear hierarchy. Top-level game areas belong in the persistent bottom `TabView`; detail flows inside a tab can use `NavigationStack`.
- Keep navigation surfaces and action surfaces distinct. Use `TabView` only for top-level destinations; use `ToolbarItem`, `Menu`, sheets, alerts, or in-content controls for contextual actions.
- Keep the interface portrait-first, thumb-reachable, and safe-area aware. Important recurring actions should remain near the bottom unless they are passive status indicators.
- Respect Dynamic Type, Reduce Motion, VoiceOver, contrast, and legibility from the beginning. Game UI can be expressive, but the app should still be understandable with assistive technologies.
- Use system icons for navigation and common actions until custom art has a clear product reason.
- Avoid inventing nonstandard controls when a familiar Apple component can do the job.

## Modern Native Styling

- Treat native SwiftUI styling as the default. Prefer system controls, `ButtonStyle`, `Menu`, `ToolbarItem`, `safeAreaInset`, sheets, tab bars, SF Symbols, Dynamic Type, and platform materials before custom chrome.
- Route recurring app chrome through shared `TrinketDesign` helpers instead of repeating raw `.buttonStyle`, material backgrounds, custom circles, or capsules in feature views.
- Use native semantic colors and materials for app chrome, and centralized `TrinketDesign` tokens for game semantics such as Keywords, health, progression, item slots, and selection states. Views should ask for the meaning they need instead of choosing one-off colors.
- Do not force button label sizes to make controls visually match. Prefer native `controlSize`, `buttonBorderShape`, `Label`, SF Symbols, `ToolbarItem`, and semantic button styles; fixed frames are acceptable for layout surfaces such as art, grids, and progress bars, but not as a first response for control chrome.
- Use `Toggle` with a native toggle style for persistent modes such as paused/running or fast/normal. Use `Button` for one-shot actions; avoid swapping icons or using prominent button styles as a custom selected state.
- Use native glass for floating controls on iOS 26 and newer, with readable material fallbacks for earlier supported OS versions. Do not simulate glass by manually lowering opacity.
- Reserve glass for controls and lightweight app chrome. Keep game content surfaces, full-art cards, stat panels, and debug tools readable and inspectable.
- When a one-off raw material or custom control style is truly intentional, leave a short `UIStyleCheck: allow` comment explaining why it should bypass the style guardrail.

## App Store Readiness

- Use only public Apple APIs and supported frameworks.
- Keep the app stable, complete enough for review, and free of placeholder functionality before submission.
- If the app uses accounts, multiplayer, cloud saves, analytics, ads, purchases, or third-party SDKs, document the data collected and why.
- If tracking is ever introduced, use AppTrackingTransparency and provide a clear purpose string.
- Use StoreKit for in-app purchases and subscriptions. Avoid custom purchase flows for digital goods.
- Use GameKit/Game Center only when features such as achievements, leaderboards, or multiplayer are truly part of the design.
- Prepare App Store metadata early: app name, subtitle, description, screenshots, privacy details, age rating, support URL, and review notes.
- Keep TestFlight in the release plan for external feedback before App Store submission.

## Swift And Code Style

- Follow Swift API Design Guidelines: clarity at call sites beats clever brevity.
- Use `UpperCamelCase` for types and protocols; use `lowerCamelCase` for properties, methods, variables, enum cases, and functions.
- Prefer value types for simple game state when practical.
- Keep models, rules, rendering, persistence, and platform services separated enough to test.
- Avoid premature managers and global state. Add structure when repeated behavior proves it needs a home.
- Add concise documentation comments to public or shared APIs when the declaration alone is not enough.

## Agent Workflow Rules

- Before major UI work, check this file and the relevant Apple reference page.
- When adding a screen, record which Apple-native navigation pattern it uses.
- For SwiftUI layout and styling changes, run simulator checks or targeted UI tests to verify visual rendering, interaction, navigation, runtime behavior, and device compatibility.
- If an implementation needs hidden tabs, invisible placeholder items, overlayed hit targets, custom tab-bar behavior, or fixed control frames to make a native component act like another component, stop and choose the closest supported SwiftUI pattern instead.
- When adding monetization, analytics, accounts, cloud services, Game Center, or external SDKs, update this file and `AGENTS.md` with privacy/App Store implications.
- For user-visible changes, run simulator checks or targeted UI tests to verify layouts and capture screenshots when they add useful visual evidence.
- Prefer linking to official docs over copying long Apple text into the repo.
- Run `./Scripts/check-ui-style.sh` after UI styling changes to catch ad hoc glass, material, button styling, button-toggle styling, or fixed-size button-label workarounds that should use native control APIs instead.
