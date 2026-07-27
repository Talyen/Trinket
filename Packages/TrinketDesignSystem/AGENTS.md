# TrinketDesignSystem-local guide

This package owns reusable SwiftUI chrome, materials, typography, motion, **and every product color token**. It may depend on `TrinketCore` only—never app features, `BattleEngine`, or `TrinketContent`. Follow the package README.

- All product colors flow through design-system public APIs (`ThemePalette`, `TrinketDesign.Colors`, domain helpers such as `Keyword+VisualStyle`, `HomesteadTint+Color`, `HomesteadResource+Color`). No system `Color.green` / raw RGB in public APIs. Feature code must consume those public APIs only — not `DesignAssetColors` or asset string names.
- Controls in testable flows must remain discoverable by XCUITest after glass styling (identifiers dropped when applied before `.glassProminent` are a known failure mode).

Design-system changes must pass package-scoped verification before handoff.
