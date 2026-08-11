# TrinketBattleRuntime-local guide

Keep this package SwiftUI-free and limited to immutable battle launch inputs,
lifecycle identity, dependency capabilities, and the `BattleRuntime` contract.
Play-owned rewards/routes stay in AppState contracts; presentation stays in
TrinketBattleFeature. Never import Persistence, AppState, BattleFeature, or the app.

Verify changes with `./Scripts/test-package.sh TrinketBattleRuntime`.
