# TrinketFeatureSupport-local guide

This package hosts three products: SwiftUI-free contracts, reusable presentation
support, and save-backed adapters. Keep those ownership boundaries and allowed
dependencies in the [package README](README.md).

None may import `TrinketBattleFeature`, `TrinketAppState`, or the app module.
FeatureSupport changes must pass package-scoped verification before handoff.
