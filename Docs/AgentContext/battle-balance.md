# Battle balance and content context

Load only for balance numbers, encounter scaling, pacing, rounding, talents, auras, or balance-sweep work.

Before retuning combat or persistence behavior, check `Docs/Product/Decisions.md` for locked decisions and `Docs/Audits/Proposals.md` for prior audit verdicts.

Headless balance sweeps: `./Scripts/balance-sweep.sh`; operating details and evidence interpretation are below. Default stdout and `.md` are a findings brief; read that, not the JSON dump. `--full-markdown` writes the old table report. `--samples` is n per identity enemy and pairs per contrast focus.

Combatants have only HP and optional Mana; player leveling is +1 HP per level and +1 Mana every two levels if they have Mana. Heroes and companions have 10% base Crit and Dodge (additive, capped at 75%); enemies have 0% Crit/Dodge and cannot gain guaranteed crit, evade, or trait-based Crit/Dodge effects. Stun/Freeze thresholds are 20% of max HP rounded via `CombatRounding` (min 1) with 25% party incoming control resistance. Enemy scaling uses `EnemyPowerCurve` with four smoothstep curves (normal HP, boss HP, normal raw damage %, boss raw damage % at L1/20/40, then uncapped logarithmic HP growth and linear raw damage growth). Universal outgoing/incoming damage percents (e.g., Chicken Coop/Pasture and enemy raw damage) stack additively and round via `CombatRounding`. Tune encounter level first, then the four curve anchors, then per-enemy HP only for outliers across ≥2 tiers.

Beyond level 40, let `t = (level - 40) / 20` and `delta = value40 - value20`.
HP is `value40 + delta * log1p(t)`; raw damage is `value40 + delta * t`.
The health tail slows fight-length growth after equipment and talent kits mature;
raw damage continues to rise against the party's growing HP. These curves have
no designed upper plateau; numeric representation remains finite.

Encounter levels are owned by `EncounterLevelResolver`: Campaign can drop at most
three below authored level and otherwise targets the active party average plus
three; Spires keep twice the floor number; Labyrinth uses party average plus
three within five-depth bands with minimum levels 1/6/11/16/…. Adjusted levels
never exceed authored level. Labyrinth keeps generating floors indefinitely.
Previews, launch, reward fallbacks, and progression simulations use these same
mode rules. Contracts uses party-average offsets through the same resolver;
[Contracts.md](../Product/Contracts.md) owns its board and reward rules. Keep
role-specific roster catch-up XP unchanged. Product direction:
[Decisions.md](../Product/Decisions.md), PD-016 through PD-021.

Hidden fight pacing (`FightPacing`) band-scales authored combat magnitudes via comeback and a progress-based clock. Passive turn-start mana drip is excluded. Percentage multipliers on combat integers round via `CombatRounding` (nearest integer, ties to even); integer division semantics remain truncating division.

Talent-tree node/row layout is authored in the talent manifest; talent-point award cadence lives in progression code. Power is flat across all rows; do not scale talent magnitude by row level. Talent-trigger names come from `CombatModifierProfile.triggerAbilityNames` (first writer wins). Holy, turn-start, and Mana cleanses use `CombatTriggerEngine.performRandomCleanses`, which resolves removal and reactions through `EffectRemovalOperation`.

Party additional-damage auras add their extra percents across living allies and log each contributor. Dodge-spawned hits can themselves be dodged but do not run `afterDodge` again. Stun/Burn/Freeze damage uses the real type pipeline rather than a raw Health hit.

## Balance sweep

Manual CLI only — **no CI gates** or scheduled automations. Use the script's
`--help` output for current modes, defaults, and tuning flags.

```sh
./Scripts/balance-sweep.sh --help
./Scripts/balance-sweep.sh --mode ability-contrast
```

The CLI writes a findings brief and JSON sidecar under the gitignored
`BalanceSweepReports/` directory. Reports remain available for comparison for 24 hours. Use the
[keep/release controls](../../Scripts/Reference.md#output-retention) when an active
investigation needs a longer window, then release its evidence when finished. The runner owns process isolation,
sampling, pacing, policy, and report schemas. Workers receive the canonical
`BalanceSweepConfig` as JSON, with only mode, concurrency, and work slice changed;
do not forward settings through a second CLI flag list. Documentation should not mirror those
defaults. Requires the current pinned Xcode (see [toolchain ladder](../../Scripts/Reference.md#toolchain-ladder)).

Within each process, `SweepWorkerPool.map` bounds concurrent simulations and
returns non-nil results in input order. Shared claims and result storage use
`Mutex`; simulation work stays outside the lock. Keep results `Sendable` rather
than bypassing concurrency checks on a shared collection.

### Reading sweep evidence

Identity runs use the same rotating Hero/Companion schedule for every enemy.
Within a complete Hero × Companion cycle every pairing is represented. Enemy
seeds use the enemy ID, so narrowing an enemy filter preserves that enemy's
samples. This sampling revision changes results from older sweeps with the same
seed; compare reports produced by the same tooling revision.

Win rates and contrast HP/round deltas exclude unfinished battles. Duration
averages include observed rounds up to the cap; they are lower bounds for
unfinished fights. A capped fight cannot count as short, but can count as long
once it exceeds the duration target. Identity findings name enemies with stalls;
contrast findings flag either side when its stall rate reaches the configured
duration flag rate and the minimum pair count. Stalls need investigation even
when the decided battles look healthy. Raw paired results and worker summaries
share one accumulation path, keyed by typed identities including tier, entity, baseline, owner, and baseline kind.
Worker merges weight HP and round deltas by decided-pair counts and recompute flags
using the parent configuration.

Affix contrasts remove or replace only the focused affix, preserving other
affixes and their rolled powers on the compared item and all shared gear.

Presence tables count an item or affix once per owner per battle, regardless of
how many equipped slots carry it. These are associations; use the paired ability,
talent, and affix modes to isolate changes. Pairing outliers can appear even when
neither partner is individually unusual. Flags are investigation candidates,
not proof of causation or a correction for testing many comparisons.

Use `--mode all` to include identity, card, talent, affix, and progression checks;
identity alone does not test every combination. Early/middle/late are fixed
loadout profiles; early affix contrasts use one starter item per party member. A lack of flags
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

Wizard's Mana Shield talent grants base Block equal to unspent Mana, capped at
six per turn, without spending Mana. Ordinary Block gain modifiers still apply;
the Mana Shield card retains its separate Mana-payment rule.

Progression simulations keep each mode's steps, cursor, and loss count together
in `InterleavingPlayerController`. Selection and advancement share that state.
Seeded matchups draw both talent kits before starter gear; preserve this order
when simplifying setup so reports remain comparable across refactors.
Fixed-party progression excludes unattuned Spires, uses the run's world seed for
floor modifiers, and keeps Spire affinity as reward metadata rather than forcing equipment.
When all remaining advancing modes have stalled, Easy Contracts provide recovery
XP through the shared level and XP rules. These jobs do not clear advancing steps
or extend the completion criterion, and are not classified as progression hotspots.
Losses retain the same recovery offer until victory. Random-stage enemy variants
have separate hotspot rows so one enemy cannot inherit another's losses.
The battle-count limit still bounds the run. Gear remains an idealized tier profile;
the Labyrinth tracker samples ten depths, not a full renewable player career.
