# Battle balance and content context

Load only for balance numbers, encounter scaling, pacing, rounding, talents, auras, or balance-sweep work.

Before retuning combat or persistence behavior, check `Docs/Product/Decisions.md` for locked decisions and `Docs/Audits/Proposals.md` for prior audit verdicts.

Headless balance sweeps: `Packages/BattleEngine/README.md` and `./Scripts/balance-sweep.sh`. Default stdout and `.md` are a findings brief; read that, not the JSON dump. `--full-markdown` writes the old table report. `--samples` is n per identity enemy and pairs per contrast focus.

Enemy scaling uses `EnemyPowerCurve` (curve anchors live there) after archetype growth. Trash uses one curve for HP and stats. Tune encounter level first, then curve anchors, then per-enemy stat shape.

Hidden fight pacing (`FightPacing`) band-scales authored combat magnitudes via comeback and a progress-based clock. Passive turn-start mana drip is excluded. Percentage multipliers on combat integers round via `CombatRounding` (nearest integer, ties to even); integer division semantics remain truncating division.

Talent-tree node/row layout is authored in the talent manifest; talent-point award cadence lives in progression code. Power is flat across all rows; do not scale talent magnitude by row level. Talent-trigger names come from `CombatModifierProfile.triggerAbilityNames` (first writer wins). Holy, turn-start, and mana cleanses go through `CombatTriggerEngine.performRandomCleanses` so `afterCleansePerformed` always runs.

Party additional-damage auras add their extra percents across living allies and log each contributor. Dodge-spawned hits can themselves be dodged but do not run `afterDodge` again. Stun/Burn/Freeze damage uses the real type pipeline rather than a raw Health hit.
