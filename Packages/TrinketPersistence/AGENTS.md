# TrinketPersistence-local guide

Persistence behavior must conform to the [persistence guide](../../Docs/AgentContext/persistence.md). This package owns the canonical SwiftData save graph and persistence stores; it never imports the app or feature UI.

Save-store harnesses (`SaveTestSupport`) live in the `TrinketPersistenceTestSupport` target of this package — not in `TrinketTestSupport` — so TestSupport stays Persistence-free and the package graph stays acyclic.

Durable store behavior must have evidence of read/write survival across reload in
`TrinketPersistenceTests`; existing coverage may suffice. New APIs do not automatically
require new tests. Apply [Testing.md](../../Docs/Platform/Testing.md) to additions and retirement.
