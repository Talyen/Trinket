# TrinketPersistence-local guide

Read `Docs/AgentContext/persistence.md` before editing. This package owns the canonical SwiftData save graph and persistence stores; it never imports the app or feature UI.

New store APIs need mutate-reload-assert coverage in `TrinketPersistenceTests`. The root task-scoped workflow selects style and package checks; for a deliberately narrow iteration, run `./Scripts/test-package.sh TrinketPersistence`.
