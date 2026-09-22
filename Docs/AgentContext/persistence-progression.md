# Persistence progression contract

Use with [persistence ownership](persistence.md) for domain commands, rewards and encounter claims.

Battle launch captures reward quantities, recipients, bonuses, and Gold-overflow
XP in `BattleRewardPlan`. `RewardSettlementInputs` projects wallet reservations
and recipient progression at a recorded production date. Content's pure settlement
produces `BattleRewardSettlement`; the same value drives the reveal and completion.
A positive net Gold award that cannot fit replaces all Gold gains with XP while
retaining any generic battle-spending field for compatibility. Current combat
content does not produce battle spending. Mystery bonuses use the same capacity
policy. Completion revalidates the recorded
snapshot and rejects stale settlements before any mode completion; the UI refreshes
its reveal before another claim. Application uses the recorded production date so
passive accrual cannot silently shrink a displayed award. Unprepared rewards use
the same settlement path. Modes retain their existing one-time claim ownership.

Contracts and Labyrinth/Voyage combat share Content's `RewardModifier` catalog.
Saved IDs stay stable; exhausted collectible bonuses resolve to Gold consistently
in artwork/details and launch loot. Keyword guarantees occupy one normal affix
slot on matching Basic/Astral equipment. New reward modifiers apply only to combat;
existing Mystery quantity bonuses remain supported.

Shared battle XP scales per recipient with enemy level. The existing smoothstep
penalty reaches zero at ten levels below the recipient; its mirrored bonus reaches
2× base XP at ten levels above and saturates there. Equal-level XP remains unchanged.
Role-specific catch-up, mode bonuses, and existing final caps still apply.

Defeat XP uses `BattleRewardPlan.settleDefeat` with the launch-baked XP for each
recipient: floor(normal XP × peak enemy health depletion / 2). Depletion records
the lowest Health percentage reached within combat resolution; healing never
reduces that progress or rewards repeating the same range. There is no turn gate.
Existing eligibility and XP caps remain; Gold overflow, loot, materials, and
encounter completion never apply. Retreat grants nothing. `BattleExperienceReward`
applies only the two XP awards in the same save transaction. The claim/navigation
sequence is owned by [battle completion](battle-launch.md).

`MysteryEncounterResolution` owns choice effects and progress together, including
required item/unlock validation; a secondary reward cannot turn an unavailable
headline reward into a successful choice. Deliberate leave is an explicit outcome.

`EncounterIdentity` scopes Journey stages and Labyrinth nodes to their world seed
and save generation. Shop offers are pinned on first opening; stock and purchased
offer IDs live in the Journey stage payload or Labyrinth node payload. Stock
survives inventory removal and reload; singleton ownership is a separate check.
`ShopPurchaseApplier` accepts an offer ID and reads saved stock, including its price.
Views and commands share its availability query. Never infer claims from inventory
ID prefixes or session flags. Homestead build commands require the displayed target
tier and validate that tier inside the transaction.

Homestead collection and build/upgrade commands are asynchronous. Local-only and
confirmed signed-out play retain the existing local transactions. Linked cloud
players can view estimated production offline, but claims/upgrades wait for the
private CloudKit authority; other gameplay remains available. Immediately before
queueing collection or an upgrade, the local snapshot must still match its
acknowledged head. Synchronize intervening gameplay first; if it changes again
while waiting, leave the production action unqueued for retry.

The authority refreshes a server timestamp using a conditional write, settles the
old production rate, and atomically commits the complete head and an immutable
operation receipt. Change-tag conflicts refetch and retry the same request ID.
Claim cursor, pending amounts, wallet application, and upgrades cannot commit
independently. A lost response or process termination replays the receipt by
installing the committed head, not by adding the reward again. The authority
sequence prevents older offline snapshots from undoing a committed claim/upgrade.
Reset epochs invalidate outstanding claims. Development and Production evidence
is required by the [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).

Voyage encounters use run-and-node identities for saved shops, Mystery offers, and one-time completion. Final battle reward plans include the [Voyage completion bonus](../Product/Voyage.md#levels-and-rewards) after ordinary reward multipliers and before capacity settlement.
