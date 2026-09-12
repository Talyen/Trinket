# TrinketContent-local guide

Catalog and manifest behavior must conform to the [content and manifests guide](../../Docs/AgentContext/content-and-manifests.md). Authored Swift is grouped by game domain under `Sources/TrinketContent/`; the [package structure](README.md#structure) maps those folders. Generated catalogs are outputs, not authored source.

Catalog inputs and generated outputs must stay in sync; generation must be idempotent. Consequential catalog invariants need evidence in `TrinketContentTests`; existing coverage may suffice. Use [Testing.md](../../Docs/Platform/Testing.md) to decide additions and retirement.
