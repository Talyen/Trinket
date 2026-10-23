# TrinketDesignSystem-local guide

This package owns reusable SwiftUI chrome, materials, typography, motion, **and every product color token**. It may depend on `TrinketCore` only. Follow the package README and [apple-design](../../.agents/skills/apple-design/SKILL.md).

Feature code must consume public design-system APIs only — not `DesignAssetColors` or asset string names. Glass CTAs must keep XCUITest identifiers (see [Testing](../../Docs/Platform/Testing.md)).

Choose static handoff or focused package verification under
[Verification.md](../../Docs/Platform/Verification.md#confidence-ladder).
Static handoff does not compile the package; CI owns broad qualification.
