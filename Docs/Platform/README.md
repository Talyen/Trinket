# Platform Documentation

Standing Apple platform guidance for Trinket. Prefer durable policy here over migration plans or dated scorecards.

| Document | Purpose |
|----------|---------|
| [Architecture.md](Architecture.md) | Module layout, dependencies, persistence, stack rules |
| [Testing.md](Testing.md) | Unit / smoke / UI ownership and verification habits |
| [iOS26AppleReference.md](iOS26AppleReference.md) | Curated WWDC and Apple documentation links |
| [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) | Pre-ship CloudKit / App Store checklist (local prep vs live enablement) |
| [IdentityPlan.md](IdentityPlan.md) | Guest-first identity: iCloud = cross-device progress; no login splash / SIWA / Google |
| [PerformanceInvestigationPlaybook.md](PerformanceInvestigationPlaybook.md) | Device-led workflow for performance, memory, or energy regressions |

Related agent audits: [Docs/Audits/README.md](../Audits/README.md). Package boundaries:
[FeatureSupport](../../Packages/TrinketFeatureSupport/README.md),
[BattleFeature](../../Packages/TrinketBattleFeature/README.md), and
[AppState](../../Packages/TrinketAppState/README.md). Design system / chrome:
[TrinketDesignSystem/README.md](../../Packages/TrinketDesignSystem/README.md). Fluid
motion: `TrinketMotion` in `Packages/TrinketDesignSystem/`. Balance sweeps:
[BattleEngine README](../../Packages/BattleEngine/README.md) and
`./Scripts/balance-sweep.sh`.
