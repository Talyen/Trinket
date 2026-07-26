# TrinketTestSupport-local guide

This package owns reusable combat/content test fixtures only (`CombatantFixtures`, battle parties). Keep fixtures deterministic and independent of app-feature UI and persistence. Do not put product rules or save-store harnesses here — those live beside PersistenceTests / TrinketTests.

Use the root task-scoped workflow to select focused consuming package tests after a fixture change; use `Docs/Platform/Testing.md` for shared test conventions.
