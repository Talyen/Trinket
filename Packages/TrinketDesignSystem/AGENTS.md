# TrinketDesignSystem-local guide

This package owns reusable SwiftUI chrome, materials, typography, motion, **and every product color token**. It may depend on `TrinketCore` only. Follow the package README and [apple-design](../../.agents/skills/apple-design/SKILL.md).

Feature code must consume public design-system APIs only — not `DesignAssetColors` or asset string names. Glass CTAs must keep XCUITest identifiers (see [Testing](../../Docs/Platform/Testing.md)).

Design-system changes use routed handoff and CI-owned package verification under
[Verification.md](../../Docs/Platform/Verification.md#local-simulator-budget).
A lightweight local handoff does not establish package-test success.
