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
- Keep the interface portrait-first, thumb-reachable, and safe-area aware. Important recurring actions should remain near the bottom unless they are passive status indicators.
- Respect Dynamic Type, Reduce Motion, VoiceOver, contrast, and legibility from the beginning. Game UI can be expressive, but the app should still be understandable with assistive technologies.
- Use system icons for navigation and common actions until custom art has a clear product reason.
- Avoid inventing nonstandard controls when a familiar Apple component can do the job.

## Game-Specific Application

- The game may look themed, but it should still feel like an iOS app: predictable navigation, stable tap targets, clear feedback, and no hidden critical actions.
- The `Play` tab is the default root because it represents the active game loop.
- `Heroes`, `Pets`, `Homestead`, and `Options` remain sibling top-level destinations. Avoid adding new tabs casually; use drill-in screens, segmented controls, filters, or sheets inside a tab first.
- Cards are the central visual object for heroes, pets, items, abilities, and equipment. Card layouts should keep a consistent 3:4 silhouette, readable names, and accessible labels.
- Prefer identity-first card presentation. Keep dense stats, formulas, comparisons, and secondary mechanics in detail sheets or drill-in views.
- Heroes, Pets, and Enemies share the first combatant Card Detail pattern: large art, name, role, health, active effects when present, and abilities with inline Keyword descriptions.
- Collection-tab combatant details show base health and no active effects; Battle combatant details show current health and active effects.
- Use progressive disclosure for game systems: explain choices in plain fantasy language first, then reveal exact values and formulas when requested.
- Use player-facing Keywords for recurring mechanics. Keywords should be highlighted inline in descriptions and remain consistent across heroes, pets, abilities, enemies, items, affixes, and status effects.
- The first combat skeleton is an idle auto-battle flow: select `Battle`, select a Hero, select a Pet, then watch both use simple Keyword abilities against one enemy.
- `Physical` and `Burn` are the first implemented Keywords. `Burn` is the first status-effect proof point, currently applies only to enemies, and stacks through independent applications whose tick damage is aggregated.
- Battle screens should prioritize large card art and health bars; move secondary details such as names, exact HP, abilities, and logs into native sheets.
- Strategy-critical information can live in enemy detail sheets and clear descriptions. Avoid extra pre-battle confirmation or inspection steps unless they improve the actual decision-making loop.
- The Battle screen can act as the current-run dashboard, but global navigation should remain predictable through the top-level tab bar. Do not make Battle compete with the app's persistent tabs as the core navigation model.
- Item screens should become a separate Card Detail pattern focused on affixes and equipment bonuses. Make a single item easy to understand on its own, and avoid automatic item comparison or "best for this hero" labels unless later inventory complexity makes that guidance necessary.
- Keep equipment out of combatant details until equipment data and rules exist; when added, Hero/Pet details may show equipped Items, while Enemies should omit equipment unless design needs it.
- Homestead presentation is undecided. Favor card-friendly, asset-light UI until the meta-progression loop proves it needs a richer visual map.
- Combat feedback should remain native SwiftUI while the battle is card-based: use stable event-driven overlays for floating text/icons and custom animated health bars for damage/healing feedback.
- Victory currently uses a full-screen-style outcome state with placeholder Experience and Rewards sections plus `Battle Again`. Do not add real rewards, currency, inventory, or progression until the core battle loop asks for them.
- Use haptics and larger animations with restraint. Save them for meaningful milestones, combat outcomes, upgrades, unlocks, and important state changes.
- Gameplay interactions should support direct touch first. Consider Game Controller support later only if the game loop benefits from it.
- Use SpriteKit when the battle presentation needs a real-time 2D scene loop, sprite layering, particles, or animation beyond ordinary SwiftUI transitions; defer it while SwiftUI can handle the current card battlefield.

## Accessibility Checklist

- Every meaningful card, control, tab, and status indicator needs an accessible name.
- Decorative images and symbols should be hidden from accessibility.
- Text should scale gracefully where possible; avoid hard-coded layouts that clip at larger content sizes.
- Do not rely on color alone for rarity, selection, warnings, damage types, or state.
- Provide clear feedback for state changes through text, visual change, and where appropriate haptics.
- Test important screens with VoiceOver and larger text before App Store submission.

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
- When adding monetization, analytics, accounts, cloud services, Game Center, or external SDKs, update this file and `AGENTS.md` with privacy/App Store implications.
- For user-visible changes, run the harness and capture simulator screenshots.
- Prefer linking to official docs over copying long Apple text into the repo.
