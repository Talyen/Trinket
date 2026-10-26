---
type: execution-plan
status: active
created: 2026-10-09
updated: 2026-10-25
expires: 2026-10-23
---

# Player coverage

## Objective and boundaries

Complete the seven approved real-player coverage areas, preserving card-play
semantics, saves, artwork and sound. The original October 9 task authorized review,
repairs, integration, push and CI follow-through. Live account operations, sync
enablement and deployment remain excluded.

Retained after the October 25 documentation review: FullUI/profile/Soak acceptance
remains incomplete in the recorded evidence. Current-main hosted coverage was not
refreshed by this documentation pass.

## Recorded status

Lifecycle/rapid-input, reward interruption, mode navigation, haptics/StoreKit,
native settings, real-backend audio, serial Soak, fixed-seed careers and populated
schema-two migration/recovery coverage were implemented. Their standing scope and
remaining device/service gates live in
[Player coverage](../Platform/PlayerCoverage.md).

Required push [37978887013](https://github.com/Talyen/Trinket/actions/runs/37978887013)
on `5dc0e104` passed all seven Smoke cases. Extended
[37979415382](https://github.com/Talyen/Trinket/actions/runs/37979415382)
passed package, parity, assets, generation/style and unsigned device Release checks;
FullUI had 13 passes and 11 failures. Player
[37979418399](https://github.com/Talyen/Trinket/actions/runs/37979418399)
passed twenty careers and interruption/recovery workers but lacked completed
profile evidence. These are historical results, not verification of current main.

## Remaining work

- [ ] Reconcile committed repairs with current main before publishing the original
  follow-up batch. `508a3b23` repairs missing Explore entry for Soak/audio/Spires;
  other repairs address navigation, sheet dismissal, queries, switches and restore fixtures.
- [ ] Verify profile fixes for invisible native titles and offscreen Settings rows
  at large text. Preserve settings restoration and validated build stamps; a
  failed prerequisite must abort dependent product assertions.
- [ ] Finish requested FullUI/profile/Soak jobs, inspect visual evidence and individual
  skips, and repair attributable failures under [Verification](../Platform/Verification.md).
- [ ] Preserve needed artifacts, report exact outcomes, and delete this plan when
  automated acceptance is complete. Live service/device qualification remains separate.

Coverage already protects draw followups, overlapping casts, finishing taps,
failed claims and stale callbacks; extend only confirmed gaps. Verify actual
repository artifact retention before relying on workflow requests: the original
run's repository cap shortened retention. Current retention policy lives in
[the command reference](../../Scripts/Reference.md#output-retention).
Earlier repair and run histories remain in this file's Git history.
