# TrinketAppState-local guide

Keep `AppState` as composition/wiring only. Do not expose a parallel `AppState.battle`
handle; shell and views use `PlaySession.battle`. Do not reintroduce a `PlaySession`
back-pointer on mode owners. Conform to [`Docs/AgentContext/battle.md`](../../Docs/AgentContext/battle.md).

Verify with `./Scripts/test-package.sh TrinketAppState`. Do not test live AVFoundation playback.
