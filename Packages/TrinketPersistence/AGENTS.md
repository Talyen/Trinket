# TrinketPersistence-local guide

Read `Docs/AgentContext/persistence.md` before editing. This package owns the canonical SwiftData save graph and persistence stores; it never imports the app or feature UI.

New store APIs need mutate-reload-assert coverage in `TrinketPersistenceTests`. Run `./Scripts/test.sh style` and `./Scripts/test-package.sh TrinketPersistence`.
