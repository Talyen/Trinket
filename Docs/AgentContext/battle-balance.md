# Battle balance and content context

Load only for balance numbers, encounter scaling, pacing, rounding, talents, auras, or balance-sweep work.

Before retuning combat or persistence behavior, read the applicable locked
[product decisions](../Product/Decisions.md) and their linked mode contracts.
[Audit proposals](../Audits/Proposals.md) preserve unresolved decisions and unique
current rationale; past verdicts do not override current product rules or serve
as permanent exceptions.

Headless balance sweeps: `./Scripts/balance-sweep.sh`; operating details and evidence interpretation are below. Default stdout and `.md` are a findings brief; read that, not the JSON dump. `--full-markdown` writes the old table report. `--samples` is n per identity enemy and pairs per contrast focus.

Combatants have only HP and optional Mana; player leveling is +2 HP per level and +1 Mana every two levels if they have Mana. Heroes and companions have 10% base Crit and Dodge (additive, capped at 75%); enemies have 0% Crit/Dodge and cannot gain guaranteed crit, evade, or trait-based Crit/Dodge effects. Stun/Freeze thresholds are 20% of max HP rounded via `CombatRounding` (min 1) with 25% party incoming control resistance. Enemy scaling uses `EnemyPowerCurve` with static mode profiles and four smoothstep curves (normal HP, boss HP, normal raw damage %, boss raw damage % at L1/20/40, then uncapped logarithmic HP growth and linear raw damage growth). Universal outgoing/incoming damage percents (e.g., Chicken Coop/Pasture and enemy raw damage) stack additively and round via `CombatRounding`. Tune encounter level first, then the four curve anchors, then per-enemy HP only for outliers across ≥2 tiers.

Beyond level 40, let `t = (level - 40) / 20` and `delta = value40 - value20`.
HP is `value40 + delta * log1p(t)`. Standard raw damage uses an explicit linear
post-kit step owned by `EnemyPowerCurve`; Spire/recovery raw damage uses
`value40 + delta * t`. Do not reuse the level-20-to-40 gear jump as standard
post-40 damage growth.
The health tail slows fight-length growth after equipment and talent kits mature;
raw damage continues to rise against the party's growing HP. These curves have
no designed upper plateau; numeric representation remains finite.

Content's `EncounterScaling` selects the encounter level and enemy power profile
together for previews, launch, reward fallbacks, and progression simulations.
`EncounterLevelResolver` supplies authored levels; its adjustment arithmetic is
internal to Content. Campaign can drop at most
three below authored level and otherwise targets the active party average plus
three; Spires keep twice the floor number; Labyrinth uses party average plus
three within five-depth bands with minimum levels 1/6/11/16/…. Adjusted levels
never exceed authored level. Labyrinth keeps generating floors indefinitely.
Previews, launch, reward fallbacks, and progression simulations use these same
mode rules. Contracts uses party-average offsets through the same policy;
[Contracts.md](../Product/Contracts.md) owns its board and reward rules. Keep
role-specific roster catch-up XP unchanged. Product direction:
[Decisions.md](../Product/Decisions.md), PD-016 through PD-021.

The standard profile serves Journey, Labyrinth, Voyage, and non-Easy Contracts.
Its level-40 Health multipliers are 30.4 for regular enemies and 60 for bosses;
raw damage bonuses are +880% and +585%. Level-1/20 anchors retain their values.
Countess's standard-profile raw damage bonus reaches +520% at level 40 through
the same smoothstep from level 20, then retains the common post-40 damage slope.
This adjustment belongs to `CombatBuildResolver`; power ratings reuse that build.
Enemy and player ability definitions remain shared and unchanged by stat tuning.
Mud Elemental has 13 base Health and Pyromancer has 11; their shared abilities
and authored traits retain their rules. These per-enemy Health adjustments apply
through the same level scaler in every mode.
Spires use their own fixed-floor power profile; Easy Contracts use the recovery
profile. Profile selection stays static for the mode, never follows party gear or
current Health. Previews, launch assembly, progression matchups, and hotspot power
ratings use the same profile. Spire levels remain twice the floor and XP rates
and catch-up rules remain unchanged.

Hidden fight pacing (`FightPacing`) band-scales authored combat magnitudes via comeback and a progress-based clock. Passive turn-start mana drip is excluded. Percentage multipliers on combat integers round via `CombatRounding` (nearest integer, ties away from zero); integer division semantics remain truncating division.

Talent-tree node/row layout is authored in the talent manifest; talent-point award cadence lives in progression code. Power is flat across all rows; do not scale talent magnitude by row level. Talent-trigger names come from `CombatModifierProfile.triggerAbilityNames` (first writer wins). Holy, turn-start, and Mana cleanses use `CombatTriggerEngine.performRandomCleanses`, which resolves removal and reactions through `EffectRemovalOperation`.

Party additional-damage auras add their extra percents across living allies and log each contributor. Dodge-spawned hits can themselves be dodged but do not run `afterDodge` again. Stun/Burn/Freeze damage uses the real type pipeline rather than a raw Health hit.

## Late-game pacing and comparison builds

[PD-034](../Product/Decisions.md) accepts the current level-60–80 pacing with
gear-aligned offensive parties: roughly 10 rounds for regular enemies and 20–25
for bosses. Retain the current enemy Health curve, including its post-40 tail.
Keep Heal, Cinderbloom, Spiked Shield and Smite at their current shared values;
players and enemies continue to use the same ability definitions.

Use these late-game reference builds in balance comparisons:

| Party | Role | Basic | Skill | Ultimate | Equipment |
|---|---|---|---|---|---|
| Druid / Panther | Offensive baseline | Maul | Cinderbloom | Thorn Mail | Retained earned gear aligned to the selected cards |
| Knight / Bear | General baseline | Slash | Spiked Shield | Earthquake | Retained earned gear aligned to the selected cards |
| Knight / Bear | Holy alternative | Slash | Smite | Earthquake | Earned Holy-focused gear |

Keep the original defensive and low-offense builds as sensitivity comparisons.
Use the reference builds above when judging global enemy Health; slower fights
from low-damage selections alone do not justify a global reduction. These
profiles guide late-game comparisons; starter selections and player loadout
choices remain unchanged.

Retain the earned-inventory progression and shared equipment-selector fixes
described below, including saved roll comparisons and journaled bow/quiver
transitions. For a card-only contrast, hold gear fixed and label that choice.
For a build comparison, choose cards first and let the selector re-equip from the
same earned inventory. Report those two experiments separately.

The pacing targets express an accepted design judgment for these reference
builds. CLI duration flags remain investigation candidates. Reopen tuning for a
new confirmed gameplay defect or a material content/progression change.

## Balance sweep

Will-o-Wisp uses Ray of Frost, Frostbolt and Blizzard. Its Basic no longer doubles
damage against an already Frozen target; player-owned Ice Shot is unchanged.

Manual CLI only — **no CI gates** or scheduled automations. Use the script's
`--help` output for current modes, defaults, and tuning flags.

```sh
./Scripts/balance-sweep.sh --help
./Scripts/balance-sweep.sh --mode ability-contrast
```

Run broad sweeps in a hosted diagnostic environment. [Verification](../Platform/Verification.md#execution-limits)
owns local admission; a short CLI default does not authorize heavy local work.

Use the default identity mode for a routine, approximately ten-minute-or-less
screen after the release binary is built. Cold compilation is additional time,
and a busy host can increase runtime. This small screen finds large encounter
and duration outliers; it does not establish roster parity or full party coverage.
Use explicit `--samples` increases and additional seeds to confirm candidates.
`--mode all` is an opt-in deep run: the full card, talent, and affix matrices can
take much longer even at the default sample count.

The CLI writes a findings brief and JSON sidecar under the gitignored
`BalanceSweepReports/` directory. Reports remain available for comparison for 24 hours. Use the
[keep/release controls](../../Scripts/Reference.md#output-retention) when an active
investigation needs a longer window, then release its evidence when finished. The runner owns process isolation,
sampling, pacing, policy, and report schemas. Workers receive the canonical
`BalanceSweepConfig` as JSON, with only mode, concurrency, and work slice changed;
do not forward settings through a second CLI flag list. Documentation should not mirror those
defaults. Requires a compatible Swift toolchain with macOS package support. Local
sweeps use the shell's selected toolchain; the required CI pin does not select it
for this command (see [toolchain ladder](../../Scripts/Reference.md#toolchain-ladder)).

Within each process, `SweepWorkerPool.map` bounds concurrent simulations and
returns non-nil results in input order. Requested work slices apply within each
selected mode before worker chunking, and the merged report retains that request.
Shared claims and result storage use
`Mutex`; simulation work stays outside the lock. Keep results `Sendable` rather
than bypassing concurrency checks on a shared collection.

### Reading sweep evidence

Identity runs use the same rotating Hero/Companion schedule for every enemy.
Both rosters cycle evenly before repeated pairings shift to cover filtered rosters
with shared divisors. The default screen represents every Hero and Companion;
within a complete Hero × Companion cycle every pairing is represented. Enemy
seeds use the enemy ID, so narrowing an enemy filter preserves that enemy's
samples. This sampling revision changes results from older sweeps with the same
seed; compare reports produced by the same tooling revision.

Win rates and contrast HP/round deltas exclude unfinished battles. Duration
averages include observed rounds up to the cap; they are lower bounds for
unfinished fights. A capped fight cannot count as short, but can count as long
once it exceeds the duration target. Identity findings name enemies with stalls;
contrast findings flag either side when its stall rate reaches the configured
stall flag rate and the minimum pair count. Below-threshold capped identity and
progression fights remain visible as unfinished diagnostics. Older JSON without
`stallFlagRate` retains its shared duration/stall threshold. The legacy
`--duration-flag-rate` flag still overrides both; a later `--stall-flag-rate`
overrides stalls separately. Stalls need investigation even
when the decided battles look healthy. Raw paired results and worker summaries
share one accumulation path, keyed by typed identities including tier, entity, baseline, owner, and baseline kind.
Worker merges weight HP and round deltas by decided-pair counts and recompute flags
using the parent configuration.
Progression findings also identify capped battles and incomplete runs, even when
there are no decided samples from which to flag a difficulty hotspot.
The headless simulator also applies Auto Battle's thirty-round no-progress budget.
This stop remains an unfinished (`timedOut`) result, not a decided defeat; it earns
no defeat XP. Combat still permits manual play or a newly enabled Auto run from
the same state. Total-round and action caps remain additional diagnostic limits.

Affix contrasts remove or replace only the focused affix, preserving other
affixes and their rolled powers on the compared item and all shared gear.

Presence tables count an item or affix once per owner per battle, regardless of
how many equipped slots carry it. Attribution includes only gear that survives
loadout sanitization, including early starter gear; unequipped inventory is excluded.
These are associations; use the paired ability,
talent, and affix modes to isolate changes. Pairing outliers can appear even when
neither partner is individually unusual. Flags are investigation candidates,
not proof of causation or a correction for testing many comparisons.
Hero and Companion peer comparisons use the same decided encounter sample as
their table, using the median of owner win rates so heavily sampled owners do
not dominate the peer baseline. Boss-only and regular-enemy tables each use
their own owner median. Enemy and progression goals use the same encounter-role
bands at every tier; Trinket has no separate Elite role. Rates of zero or one
are flagged once the minimum decided sample is met, even if the confidence
interval overlaps the target band. Other enemy/hotspot flags require the
confidence interval to exclude the band.

Use `--mode all` to include identity, card, talent, affix, and progression checks;
identity alone does not test every combination. Early/middle/late are fixed
loadout profiles; early affix contrasts use one starter item per party member.
Themed gear uses authored Trinkets, with their own signature alignment, rather than
rolling ordinary gear affixes onto Trinket bases. This changes seeded builds from
older sweeps; compare reports produced by the same gear-generation revision. A lack of flags
with sparse samples or omitted modes does not establish balance. Increase
`--samples`, confirm across seeds, and use `--policy-compare` to check whether an
identity finding depends on autoplay choices. Durations are battle rounds, not
wall-clock seconds or animation timings.

Paired contrasts use shared legal talent kits and starter equipment in the early
profile. The focused talent choice is excluded from the common background kit;
both resulting builds must remain legal. The minimal-talent diagnostic omits
background talents and retains the focus's prerequisites. Shared kits leave points
unspent when using them would require the opposing focus or an illegal later row.
The diagnostic is labeled separately; older JSON reports without the build-context field retain
their historical minimal-talent interpretation. Do not compare those results as
if they were tier-kit evidence.

Duration buckets and identity tables share one classification path. Enemy duration
rows keep boss and regular encounters separate even when their IDs match; Hero and
Companion rows combine opponents using each encounter's duration band. Equal long-fight
rates select the alphabetically first eligible enemy so repeated reports stay stable.

Talent contrasts include every authored row. A focused node is compared with
its sibling when present, or with the same prerequisite build without that node
for a single-node row. Reordered nodes use their current positions for legality;
tiers without enough talent points are skipped rather than given illegal builds.
Gold talent comparisons remain eligible for findings: their Block, damage, draw,
and healing effects can change combat outcomes. Do not suppress a whole tree
based on its keyword.

Bounty Shot deals 3 Stun damage and has a 30% chance to steal 1 Gold.
Its base expected Gold remains 0.3 per play; theft-triggered Talents activate more often.

Wizard's Mana Shield talent grants base Block equal to unspent Mana, capped at
six per turn, without spending Mana. Ordinary Block gain modifiers still apply;
the Mana Shield card retains its separate Mana-payment rule.

Progression simulations keep each mode's steps, cursor, and loss count together
in `InterleavingPlayerController`. Selection and advancement share that state.
New progression configurations default to retained earned gear. Each fresh run
starts ungeared, chooses abilities once, spends talent points cumulatively through
legal unlocks, and retains its inventory. Only victories award items through the
shared loot resolver at the fought encounter level, including ownership exclusion,
active-party loot bias, the opening Journey boss reward and seeded Spire rewards.
The shared `SimulationEquipmentPolicy` accepts strict whole-loadout improvements,
retains ties, respects ownership, and supports secondary slots. Bow-to-melee upgrades
include any required quiver removal in the complete-loadout score and expose that
removal before the equip command. Both the headless and save-backed runners apply
the same plan through their owning equipment operations. It checks resolved
modifier effects for resistance and Mana usability instead of treating affinity tags
as activation requirements. Shared-damage bonuses are evaluated on the whole candidate
loadout; they do not grant the source damage type's attacks or procs. Saved modifier
and trigger roll magnitudes break ties only between the same affix portfolio, rarity
and hand multiplier, with no magnitude reduced. The versioned policy is
still a heuristic, not an estimate of optimal combat value; conditional effects retain
coarse keyword alignment. Compare reports with their recorded policy IDs. Shops, crafting,
Corruption, wishes and Homestead bonuses are outside this headless model.

`--progression-gear tier` retains the historical idealized benchmark, including its
level-35 Basic-to-Astral switch and per-battle ability/talent/gear draws. Historical
JSON without an equipment-model field retains that interpretation. Legacy seeded
matchups draw both talent kits before starter gear; preserve that draw order when
simplifying setup. Identity and contrast modes remain fixed tier benchmarks.
Fixed-party progression includes every Spire, uses the run's world seed for
floor modifiers, and keeps Spire affinity as reward metadata rather than forcing equipment.
When all remaining advancing modes have stalled, Easy Contracts provide recovery
XP through the shared level and XP rules. These jobs do not clear advancing steps
or extend the completion criterion, and are not classified as progression hotspots.
Decided defeats earn the existing partial XP from peak enemy Health depletion,
using `BattleDefeatProgress.experienceAward`; unfinished capped simulations earn
no defeat XP. Defeats do not clear advancing content or count as victories.
Reports from the earlier victory-only career model overstate recovery grind and
must not be compared as if they included live defeat rewards.
Losses retain the same recovery offer until victory. Random-stage enemy variants
have separate hotspot rows so one enemy cannot inherit another's losses.
The battle-count limit still bounds the run; the Labyrinth tracker samples ten
depths, not a full renewable player career. `BalanceProgressionRunner.earnedCheckpoints`
continues with renewable Easy Contracts after the finite mode sample, freezing
inventory and selections at requested levels. Reports must disclose this training
route and incomplete targets; probe fights do not award progression. Compare gear
models with the same checkpoint abilities, talents, encounter and battle seed;
do not treat drop-weighted single snapshots as accumulated earned equipment.
