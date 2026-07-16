# TrinketDesignSystem-local guide

This package owns reusable SwiftUI chrome, materials, typography, motion, **and every product color token**. It may depend on `TrinketCore` only—never app features, `BattleEngine`, or `TrinketContent`.

- Add new colors as `DesignColors.xcassets` colorsets and expose them through `DesignAssetColors` → `ThemePalette` / `TrinketDesign.Colors` or domain helpers (`Keyword+VisualStyle`, `HomesteadTint+Color`, `HomesteadResource+Color`). Do not leave system `Color.green` / raw RGB in public APIs.
- Feature code must consume those public APIs only; do not teach call sites to use `DesignAssetColors` or asset string names directly.
- Pass XCUITest selectors into `trinketPrimaryActionButton(accessibilityIdentifier:)` so the id is applied *after* `.glassProminent`. Attaching `.accessibilityIdentifier` before the glass style drops the id from the AX tree.
- Follow the package README. The root task-scoped workflow selects style and package checks; for a deliberately narrow iteration, run `./Scripts/test-package.sh TrinketDesignSystem`.
