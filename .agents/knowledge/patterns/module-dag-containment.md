# Module DAG and hub containment

Convenience imports and forwarding methods can make a local change look small
while moving behavior away from its owner. Past additions to `BattleState`,
`PlayerSaveStore`, and `AppState` repeatedly created this pressure.

Use the [architecture map](../../../Docs/Platform/Architecture.md) for the current
dependency graph and hub extension points. Do not maintain a second graph here.
[check-module-boundaries.sh](../../../Scripts/check-module-boundaries.sh) catches
forbidden edges, but it cannot prove a method belongs on a hub. Inspect both the
new operation and its callers before treating a passing check as containment.

A proposed split has a separate evidence bar: consult
[deferred seams](architecture-deferred-seams.md). The trigger differs by seam;
“a third consumer” is not a universal prerequisite or automatic approval.
