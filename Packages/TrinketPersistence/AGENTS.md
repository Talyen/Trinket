# TrinketPersistence-local guide

Persistence behavior must conform to the [persistence guide](../../Docs/AgentContext/persistence.md). This package owns the canonical SwiftData save graph and persistence stores; it never imports the app or feature UI.

Save-store harnesses (`SaveTestSupport`) live in the `TrinketPersistenceTestSupport` target of this package — not in `TrinketContentTestSupport` — so shared combat fixtures stay Persistence-free and the package graph stays acyclic.

Durable store behavior must have evidence of read/write survival across reload in
`TrinketPersistenceTests`; existing coverage may suffice. Use [Testing.md](../../Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior)
to decide whether new coverage is needed.
