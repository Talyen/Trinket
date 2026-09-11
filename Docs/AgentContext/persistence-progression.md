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
