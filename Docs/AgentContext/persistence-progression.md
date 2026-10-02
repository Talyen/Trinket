# Persistence progression contract

Use with [persistence ownership](persistence.md) for domain commands, rewards and encounter claims.

`BattleLoot.resolve` owns seeded battle drops for every mode. `LootRequest` carries
mode identity and bonuses; the captured encounter level drives both item quality
and currency quantities. Noncombat offers retain `CampaignRewardLevel` policy.
`VictoryRewardApplier` owns reward application to the save.

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
Contract victories record the completed offer ID before replacement; refreshing the board preserves receipts
without creating a claim. Voyage victories record completed run IDs before
dismissing their cleared routes.

Contracts and Labyrinth/Voyage combat share Content's `RewardModifier` catalog.
Voyage destination offers save a separate modifier for the final boss victory;
its XP bonus is excluded from partial-defeat XP. When both destination and node
modifiers affect items, the final reward plan carries both rolls so the reveal
and committed award remain identical.
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

Corruption gives each successfully added or replaced affix one numeric bump at the
item's final rarity: increase/decrease odds use the existing 40:20 weights (two to
one), changing one eligible value by 1 or one percentage point. A decrease that
cannot respect the 1 / 1% minimum becomes an increase. On/off affixes stay eligible
without a numeric bump. The independent item-wide 40% increase and 20% decrease
rolls target only surviving original affixes, preventing extra bumps on new affixes.
Existing corrupted items are unchanged; structural selection and corruption-mark
priority retain their existing rules. Items with affixes absent from the current
catalog remain saved intact and are ineligible for corruption; the altar must not
partially rebuild their affixes or powers.

Mystery opening pins the chosen event and prepares any saved offers in one
transaction; rejected offers leave no new pin, and the session appears only
after the save commits. `MysteryEncounterResolution` owns choice effects and
progress together, including required item/unlock validation. Mystery requests,
offer preparation, and claims use one required `EncounterIdentity`; levels, payloads,
and completion derive from its location rather than a parallel stage or optional
node ID. Direct choices receive normal noncombat completion rewards; pooled offers
already include their payout and only advance progress. An opened offer
stays claimable; a duplicate Unique already earned on another device is kept
once while its secondary reward and encounter completion proceed. Deliberate
leave is an explicit outcome. `MysteryEncounterSession` owns transient screen
state with a payload per presentation; returning to choices releases prior reveal
and reward data. Choice-attempt status is separate so a save failure retains the
current screen and its payload for retry. Views read projections of these states;
phase, result payloads, resolving status, and failure text are not independently
mutable.

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
