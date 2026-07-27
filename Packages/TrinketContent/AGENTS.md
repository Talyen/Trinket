# TrinketContent-local guide

Catalog and manifest behavior must conform to `Docs/AgentContext/content-and-manifests.md`. Catalog source lives in manifests and `Sources/TrinketContent/Content/`; generated catalogs are outputs, not authored source.

Catalog inputs and generated outputs must stay in sync; generation must be idempotent. Catalog invariant changes need coverage in `TrinketContentTests`. Package-scoped verification must pass before handoff.
