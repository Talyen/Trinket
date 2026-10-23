# Persistence progression contract

Use with [persistence ownership](persistence.md) for domain commands, rewards and encounter claims.

## Reward levels

Content's `BattleLootContext` owns mode-specific loot from explicit world seed,
collectible ownership, claimed Journey reward IDs, Sanctum bonuses and captured
party weighting. [Random item rewards](../../Packages/TrinketContent/README.md#random-item-rewards)
owns shared level selection, caps, boss guarantees, weighting and exhaustion rules.
Launch and unsettled completion use that same policy. Persistence supplies the
save-value adapter and `VictoryRewardApplier` commits the award; completion appliers
expose no parallel loot-planning API. `BattleLoot.resolve` rolls the captured
`LootRequest` identity/bonuses. Unsettled completion uses Content's `EncounterScaling`,
including fixed Spire floor levels.

## Victory settlement

Content's `BattleRewardPlan.forEncounter` constructs both launch and unsettled
encounter plans from captured party, Homestead, loot, and eligibility values.
AppState and Persistence adapt those inputs; they do not calculate parallel reward
plans. `RewardExperiencePolicy.battleExperienceAward` owns recipient catch-up,
percentage bonuses, and the normal XP cap, including for progression simulations.
Battle launch captures the selected party’s victory Gold Talent percentage alongside
Homestead Gold bonuses; both apply additively to encounter and earned combat Gold
before spending. Later party changes or Companion defeat do not revoke the captured
bonus. Defeat and noncombat rewards do not receive it.
Battle launch captures reward quantities, recipients, bonuses, and Gold-overflow
XP in that plan. `RewardSettlementInputs` projects wallet reservations
and recipient progression at a recorded production date. Content's pure settlement
produces `BattleRewardSettlement`; the same value drives the reveal and completion.
A positive net Gold award fills available wallet space; only the excess becomes
XP in proportion to the overflow fraction of the original award. Preserve generic
battle spending in the net calculation for compatibility. Current combat content
does not produce battle spending. Content's `MysteryRewardResolver` owns Mystery
generation and settlement from explicit ownership, Homestead, and reward inputs.
Persistence owns pinning and claim writes.
Mystery offers pin their item and nominal bonus
when opened, show a Gold/XP split when initially needed, and convert any further
Gold overflow at claim. Reward arithmetic saturates at integer limits, including Voyage completion
bonuses and saved run totals; ordinary reward amounts retain their existing values.
Completion revalidates the recorded
snapshot and rejects stale settlements before any mode completion; the UI refreshes
its reveal before another claim. Application uses the recorded production date so
passive accrual cannot silently shrink a displayed award. The save command accepts
the settled award and captured encounter level; it does not accept a second loot, item, material, or battle-Gold payout. Internally,
`EncounterRewards` selects either that settled award or unsettled encounter
inputs. Only unsettled inputs enter loot generation and current bonus settlement.
Modes retain their existing one-time claim ownership.
Contract victories record the completed offer ID before replacement; refreshing the board preserves receipts
without creating a claim. Voyage victories record completed run IDs before
dismissing their cleared routes.

Battle registrations retain one `BattleRewardClaim` issued by their `PlayerSaveStore`.
The claim captures the store, save generation, world identity, destination,
and recipient IDs. Persistence validates that source and the settlement's recorded
economic inputs before writing; stale or foreign claims reject without publishing.
Victory and defeat share consumption, which advances only after a durable commit.
Storage failures leave the claim retryable. Cloud metadata updates that preserve
the local save generation preserve its claims. These claims are transient and add no
battle-resume or player-save schema.

Persistence-owned battle commands resolve complete committed actions, deriving
economic receipts from their recorded changes with one claim identity per award
in a batch.
AppState supplies the retained claim and award and handles presentation after commitment;
it cannot open a save mutation closure. Standalone victories
and defeat XP carry unclaimed effects; normal battle/Salvage claims retain their
domain identities. Failed or rejected transactions publish neither awards nor receipts.

## Reward modifiers

Content's [shared modifier contract](../../Packages/TrinketContent/README.md#shared-reward-modifiers)
owns eligibility, amounts, tier/family/keyword guarantees, exhaustion fallbacks,
and Voyage's composed destination reward. Persistence retains saved modifier IDs;
preview, launch and commit resolve the same effective modifier and composed award.
The final plan carries every roll, including Voyage's separate destination item,
so reveal and claim cannot diverge. Destination rewards require final boss victory;
their XP bonus never contributes to partial-defeat XP. Existing Mystery quantity
bonuses remain readable; new reward modifiers apply only to combat.

## Battle experience

`ExperienceScaling.baseBattleAward` divides the level's unchanged XP requirement by
a target battle count: linear interpolation from 3 at level 1 to 4 at level 20 to
5 at level 40, holding at 5 afterward. Awards retain integer rounding and a minimum
of 1 XP. This base also drives Mystery XP and Gold-overflow XP; saved progression
and pinned rewards retain their values.

Shared battle XP scales per recipient with enemy level. The existing smoothstep
penalty reaches zero at ten levels below the recipient; its mirrored bonus reaches
2× base XP at ten levels above and saturates there. Equal-level encounters use base XP.
Role-specific catch-up, mode bonuses, and existing final caps still apply.

Defeat and retreat XP use `BattleRewardPlan.settleDefeat` with launch-baked XP
for each recipient: floor(normal XP × peak enemy health depletion / 2). Depletion records
the lowest Health percentage reached within combat resolution; healing never
reduces that progress or rewards repeating the same range. There is no turn gate.
Existing eligibility and XP caps remain; Gold, Gold-overflow XP, items, materials,
and encounter completion never apply. `BattleExperienceReward`
applies only the two XP awards in the same save transaction. The claim/navigation
sequence is owned by [battle completion](battle-launch.md).

## Corruption and Salvage

Item eligibility, Corruption rolls/result values, and Salvage yields belong to
`TrinketContent/Equipment`; see [item transformations](../../Packages/TrinketContent/README.md#item-transformations).
Persistence owns item lookup/replacement/removal, unequipping, material grants,
economic receipts, and the Corruption Altar cooldown.

Salvage and Corruption appliers return typed domain results consumed directly by
`persistTransaction`. Store commands distinguish committed results, rejected
actions, and storage failure; a rejected action never enters commit.

## Mystery claims

Mystery opening pins the chosen event and prepares any saved offers in one
transaction; rejected offers leave no new pin, and the session appears only
after the save commits. `prepareMysteryEncounter` and `resolveMysteryEncounter`
own these transactions in Persistence. Event selection and preview use
`EncounterIdentity.mysteryEvent(in:)` against the save and catalog. Labyrinth maps
use Persistence's immutable `LabyrinthMysteryPreview`, which shares that selection
policy while reading only map, seed/generation, unlock, inventory, cooldown, and
access inputs. Cache a floor's resolved previews only while those inputs and its
cluster remain equal. The prepared
result supplies presentation; recruits also pin before opening. Saved pins win
over later selection hints. Interrupted recruit pins use normal roster substitution
when that combatant was unlocked elsewhere. Requests carry an expected event ID,
never executable effects; ordinary choices and corruption must match the authoritative
event before mutation. Unreadable pins reject without replacement.

`MysteryEncounterResolution` owns choice effects and progress together, including required item/unlock validation. Mystery requests,
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

## Shop stock and encounter identity

`EncounterIdentity` scopes Journey stages, Labyrinth nodes, and Voyage run/node
pairs to their world seed and save generation. Shop offers are pinned on first
opening; stock and purchased offer IDs live in the corresponding Journey stage,
Labyrinth node, or Voyage node payload. A cloud import can change local session
generation without invalidating saved stock;
current commands still require the new generation. Stock survives inventory
removal and reload; singleton ownership is a separate check.
`ShopPurchaseApplier` accepts an offer ID and reads saved stock, including its price.
Views and commands share its availability query. Never infer claims from inventory
ID prefixes or session flags. Homestead build commands require the displayed target
tier and validate that tier inside the transaction.

Purchase receipts retain the pinned offer's exact item and price; upgrade receipts
retain the costs paid for that installed tier. Replay does not read current authored
prices to reconstruct these charges.

## Noncombat completion

`NonCombatEncounterCompletion` owns Journey, Labyrinth, and Voyage progress for
Shops and Mystery events. It requires a current playable `EncounterIdentity`;
stale sessions and combat nodes cannot grant rewards or advance progress.
Direct choices receive normal encounter rewards; pooled Mystery offers only advance
progress. Empty Shops prepare stock and complete in one transaction.
Shop and Mystery callbacks require their captured session and its current save
generation before acting, including retry submission. Retired callbacks leave current
progress and presentation untouched; external-progress cleanup retires obsolete covers.
Failed writes retain the session and retry silently.

## Homestead transactions

Content's `PlayerHomesteadState` owns production, collection, affordability, and
upgrade math using Gold values, with the wallet bound in Core's `GoldBalance`.
Persistence owns saved Gold, Homestead graph mapping/sanitization, admission,
and receipts; cloud replay uses the same Content rules with historical Gold.
Build/upgrade commands accept only a node ID and the displayed target tier.
The shared Persistence mutation resolves the canonical Content definition on each
attempt, for both local commands and legacy cloud production actions. Callers
cannot supply prices or tier definitions; affordability, deduction, and receipts
use that same resolved tier.
The Homestead value's Codable fields and the SwiftData graph remain unchanged.

Homestead collection and build/upgrade commands are asynchronous. Linked cloud
players collect and upgrade locally after a durable write, including offline;
the next synchronization merges accepted actions without player prompts.

Pending server production receipts remain replay-safe. Durable local actions are
identified and replayed by uploads carrying an acknowledged base snapshot;
concurrent branches merge earned progress
and the production cursor within the same reset epoch. Distinct upgrades survive
even when their combined material spend exceeds the old balance; floor that
balance at zero. Overlapping production collections count once. Local and cloud
collection debits retain unpaid production credit even when converting the
collected integer to `Double` would round it upward.
Reset epochs invalidate outstanding claims. Development and Production evidence
is required by the [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).

## Voyage identities

Voyage encounters use run-and-node identities for saved shops, Mystery offers, and one-time completion. Final battle reward plans include the [Voyage completion bonus](../Product/Voyage.md#levels-and-rewards) after ordinary reward multipliers and before capacity settlement.
