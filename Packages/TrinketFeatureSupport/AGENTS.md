# TrinketFeatureSupport-local guide

This package hosts three products: SwiftUI-free contracts, reusable presentation
support, and save-backed adapters. Keep those ownership boundaries and allowed
dependencies in the [package README](README.md).

None may import `TrinketBattleFeature`, `TrinketAppState`, or the app module.
FeatureSupport changes use routed handoff and CI-owned package verification under
[Verification.md](../../Docs/Platform/Verification.md#local-simulator-budget).
A lightweight local handoff does not establish package-test success.
