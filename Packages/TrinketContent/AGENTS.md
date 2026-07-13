# TrinketContent-local guide

Read `Docs/AgentContext/content-and-manifests.md` before editing. Catalog source lives in manifests and `Sources/TrinketContent/Content/`; generated catalogs are outputs, not authored source.

Run generation after catalog-input changes and cover invariants in `TrinketContentTests`. The root task-scoped workflow selects generation, style, and package checks; for a deliberately narrow iteration, run `./Scripts/test-package.sh TrinketContent`.
