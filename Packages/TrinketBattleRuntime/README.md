# TrinketBattleRuntime

SwiftUI-free battle lifecycle contract shared by app orchestration and the concrete
Battle feature.

## Ownership

| Type | Role |
|---|---|
| `BattleRuntime` | Lifecycle and command boundary used by `TrinketAppState` |
| `BattleRunConfiguration` | Immutable, launch-baked simulation inputs |
| `BattleRunKey` | Stable identity for prepared and active runs |
| `BattleRuntimeDependencies` | Closure-only options, audio, and feedback capabilities |
| `BattlePerformanceScenario` / `BattlePerformanceFixture` | Shared deterministic performance-harness contracts |

Play-owned route, reward, and presentation metadata does not belong here. The
concrete production implementation is `TrinketBattleFeature.BattleSession`; this
package must not import SwiftUI, `TrinketBattleFeature`, `TrinketAppState`,
Persistence, or the app module.

## Testing

This package is a contracts-only library; its behavior is exercised through the
`BattleSession` tests in TrinketBattleFeature and the AppState integration tests.
