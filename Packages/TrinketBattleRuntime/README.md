# TrinketBattleRuntime

SwiftUI-free battle lifecycle contract shared by app orchestration and the concrete
Battle feature.

## Ownership

| Type | Role |
|---|---|
| `BattleRuntime` | Lifecycle and command boundary used by `TrinketAppState` |
| `BattleRuntimeStore` | Presentation-free fallback/test implementation of that contract |
| `BattleRunConfiguration` | Immutable, launch-baked simulation inputs |
| `BattleRunKey` | Stable identity for prepared and active runs |
| `BattleRuntimeDependencies` | Closure-only options, audio, and feedback capabilities |
| `BattlePerformanceScenario` / `BattlePerformanceFixture` | Shared deterministic performance-harness contracts |

Play-owned route, reward, and presentation metadata does not belong here. The
concrete production implementation is `TrinketBattleFeature.BattleSession`; this
package must not import SwiftUI, `TrinketBattleFeature`, `TrinketAppState`,
Persistence, or the app module.

## Testing

```sh
./Scripts/test-package.sh TrinketBattleRuntime
```

Keep lifecycle transition and contract tests in `TrinketBattleRuntimeTests`.
