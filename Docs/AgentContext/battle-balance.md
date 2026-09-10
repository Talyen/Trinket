# Battle balance and content context

Load only for balance numbers, encounter scaling, pacing, rounding, talents, auras, or balance-sweep work.

Before retuning combat or persistence behavior, check `Docs/Product/Decisions.md` for locked decisions and `Docs/Audits/Proposals.md` for prior audit verdicts.

Headless balance sweeps: `Packages/BattleEngine/README.md` and `./Scripts/balance-sweep.sh`. Default stdout and `.md` are a findings brief; read that, not the JSON dump. `--full-markdown` writes the old table report. `--samples` is n per identity enemy and pairs per contrast focus.

Combatants have only HP and optional Mana; player leveling is +1 HP per level and +1 Mana every two levels if they have Mana. Heroes and companions have 10% base Crit and Dodge (additive, capped at 75%); enemies have 0% Crit/Dodge and cannot gain guaranteed crit, evade, or trait modifiers. Stun/Freeze thresholds are 20% of max HP rounded via `CombatRounding` (min 1) with 25% party incoming control resistance. Enemy scaling uses `EnemyPowerCurve` with four smoothstep curves (normal HP, boss HP, normal raw damage %, boss raw damage % at L1/20/40, then uncapped logarithmic HP growth and linear raw damage growth). Universal outgoing/incoming damage percents (e.g., Chicken Coop/Pasture and enemy raw damage) stack additively and round via `CombatRounding`. Tune encounter level first, then the four curve anchors, then per-enemy HP only for outliers across ≥2 tiers.

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

Talent-tree node/row layout is authored in the talent manifest; talent-point award cadence lives in progression code. Power is flat across all rows; do not scale talent magnitude by row level. Talent-trigger names come from `CombatModifierProfile.triggerAbilityNames` (first writer wins). Holy, turn-start, and mana cleanses go through `CombatTriggerEngine.performRandomCleanses` so `afterCleansePerformed` always runs.

Party additional-damage auras add their extra percents across living allies and log each contributor. Dodge-spawned hits can themselves be dodged but do not run `afterDodge` again. Stun/Burn/Freeze damage uses the real type pipeline rather than a raw Health hit.
