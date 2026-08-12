# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, battle parties).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`TrinketPersistenceTestSupport` beside PersistenceTests.

Validate fixture changes in consuming packages’ tests before handoff. Shared
conventions: `Docs/Platform/Testing.md`.

```sh
./Scripts/test-package.sh TrinketTestSupport
```
