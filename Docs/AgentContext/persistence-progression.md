# Persistence progression contract

Use with [persistence ownership](persistence.md) for domain commands, rewards and encounter claims.

Battle launch captures reward quantities, recipients, bonuses, and Gold-overflow
XP in `BattleRewardPlan`. `RewardSettlementInputs` projects wallet reservations
and recipient progression at a recorded production date. Content's pure settlement
produces `BattleRewardSettlement`; the same value drives the reveal and completion.
A positive net Gold award fills available wallet space; only the excess becomes
XP in proportion to the overflow fraction of the original award. Preserve generic
battle spending in the net calculation for compatibility. Current combat content
does not produce battle spending. Mystery offers pin their item and nominal bonus
when opened, show a Gold/XP split when initially needed, and convert any further
Gold overflow at claim. Reward arithmetic saturates at integer limits, including Voyage completion
bonuses and saved run totals; ordinary reward amounts retain their existing values.
Completion revalidates the recorded
snapshot and rejects stale settlements before any mode completion; the UI refreshes
its reveal before another claim. Application uses the recorded production date so
passive accrual cannot silently shrink a displayed award. Unprepared rewards use
the same settlement path. Modes retain their existing one-time claim ownership.

Contracts and Labyrinth/Voyage combat share Content's `RewardModifier` catalog.
Rare-tier odds bonuses double the named eligible tier's weight.
Saved IDs stay stable; exhausted collectible bonuses resolve to Gold consistently
in artwork/details and launch loot. Keyword guarantees occupy one normal affix
slot on matching Basic/Astral equipment. New reward modifiers apply only to combat;
existing Mystery quantity bonuses remain supported.
Item-family guarantees filter the normal single item to Weapon, Armor, Ring, or
Amulet bases at Basic/Astral tier odds; guaranteed Astral, Trinket, and Unique
tiers use their named tier directly. Exhausted collectible guarantees use the
same Gold fallback as collectible weight bonuses.

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
required item/unlock validation. An opened offer stays claimable; a duplicate
Unique already earned on another device is kept once while its secondary reward
and encounter completion proceed. Deliberate leave is an explicit outcome.

`EncounterIdentity` scopes Journey stages and Labyrinth nodes to their world seed
and save generation. Shop offers are pinned on first opening; stock and purchased
offer IDs live in the Journey stage payload or Labyrinth node payload. A cloud
import can change local session generation without invalidating saved stock;
current commands still require the new generation. Stock survives inventory
removal and reload; singleton ownership is a separate check.
`ShopPurchaseApplier` accepts an offer ID and reads saved stock, including its price.
Views and commands share its availability query. Never infer claims from inventory
ID prefixes or session flags. Homestead build commands require the displayed target
tier and validate that tier inside the transaction.

Homestead collection and build/upgrade commands are asynchronous. Linked cloud
players collect and upgrade locally after a durable write, including offline;
the next synchronization merges accepted actions without player prompts.

Pending server production receipts remain replay-safe. Durable local actions are
identified and replayed by uploads carrying an acknowledged base snapshot;
concurrent branches merge earned progress
and the production cursor within the same reset epoch. Distinct upgrades survive
even when their combined material spend exceeds the old balance; floor that
balance at zero. Overlapping production collections count once.
Reset epochs invalidate outstanding claims. Development and Production evidence
is required by the [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).

Voyage encounters use run-and-node identities for saved shops, Mystery offers, and one-time completion. Final battle reward plans include the [Voyage completion bonus](../Product/Voyage.md#levels-and-rewards) after ordinary reward multipliers and before capacity settlement.
