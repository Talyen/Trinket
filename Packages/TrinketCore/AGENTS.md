# TrinketCore-local guide

`TrinketCore` owns stable domain primitives: effects, stats, enums, and progression. Keep it independent of the app and feature UI; avoid importing higher-level packages.

Domain rules changed here must have coverage in `TrinketCoreTests` that would fail on the old behavior. Package-scoped verification must pass before handoff.
