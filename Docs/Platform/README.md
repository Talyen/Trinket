# Platform Documentation

Standing engineering policy. Product decisions live in [Docs/Product/Decisions.md](../Product/Decisions.md). Doc layers: [Docs/README.md](../README.md).

| Document | Purpose |
|----------|---------|
| [Architecture.md](Architecture.md) | Module layout, DAG, hub containment |
| [Testing.md](Testing.md) | Unit / smoke / UI conventions and keep/drop rubric |
| [Verification.md](Verification.md) | Task routing, gate composition, CI, style, and handoff |
| [SimulatorOperations.md](SimulatorOperations.md) | Managed simulator isolation and local Xcode operations |
| [Purchases.md](Purchases.md) | StoreKit testing, purchase ownership, and release prerequisites |
| [Release.md](Release.md) | Versions, release notes, tags, and App Store handoff |
| [ApplePlatformReference.md](ApplePlatformReference.md) | iOS support, adoption, and Apple design/API choices |
| [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) | Human CloudKit / App Store enablement checklist |
| [AppStoreMetadata.md](AppStoreMetadata.md) | App Store field drafts (data, not policy); procedure in Release.md |
| [PerformanceInvestigationPlaybook.md](PerformanceInvestigationPlaybook.md) | Frame-pacing + device memory/energy investigation only — do not run unless the task is performance |

Related: [Audits](../Audits/README.md), [Identity](../Product/Identity.md), [Product](../Product/README.md).
