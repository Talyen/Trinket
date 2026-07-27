# TrinketTestSupport-local guide

This package owns reusable combat/content test fixtures only (`CombatantFixtures`, battle parties). Keep fixtures deterministic and independent of app-feature UI and persistence. Do not put product rules or save-store harnesses here — those live beside PersistenceTests / TrinketTests.

Fixture changes must be validated in consuming packages’ tests before handoff. Shared conventions: `Docs/Platform/Testing.md`.
