# TrinketPersistence-local guide

Persistence behavior must conform to `Docs/AgentContext/persistence.md`. This package owns the canonical SwiftData save graph and persistence stores; it never imports the app or feature UI.

Save-store harnesses (`SaveTestSupport`) live under PersistenceTests support — not in `TrinketTestSupport` — so TestSupport stays Persistence-free and the package graph stays acyclic.

New store APIs must prove read/write survival across reload in `TrinketPersistenceTests`.
