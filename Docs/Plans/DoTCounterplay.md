---
type: execution-plan
status: active
created: 2026-09-19
updated: 2026-09-19
expires: 2026-10-03
---

# Burn and Poison counterplay

## Objective

Make Block an effective counter to Burn and Poison, using the same combat rules
and ability behavior for players and enemies. The user approved implementation
of the universal damage rule and Combustion copy. Enemy passive reworks remain
proposals. Do not run the full balance simulation for this investigation.

## Accepted direction

- The user confirmed that stacks equaling actual Health damage was always the
  intended behavior. Treat the current mismatch as a correctness defect, not
  merely an optional balance adjustment. Bonus damage belongs in that result.
- Burn and Poison applied by a damaging hit should equal the actual Health damage
  that hit deals to its recipient. A 4-damage hit with 2 absorbed applies 2 stacks;
  a fully absorbed hit applies none. Apply this universally to both sides.
- Use the damage result, including mitigation, rather than subtracting nominal
  Block from the listed ability magnitude. Dodge and zero Health damage produce
  no attached stacks. Resolve each damage component separately.
- Avoid enemy-only ability variants, enemy-only stack conversion, or different
  player/enemy decay rules. Earlier suggestions for those approaches are withdrawn.
- Keep Burn and Poison distinct: Burn fades quickly; Poison persists longer.
- Scope the requested conversion to Burn and Poison; do not silently change Bleed.

## Implementation and verification

The previous implementation attached the pre-resolution component amount, even
when Block absorbed all damage. Profile damage bonuses increased damage but not
stacks; earlier bonuses such as Kindling increased both. The fix uses the resolved
Health loss for damaging attacks and effect/reaction applications, for both sides.

The user approved that outgoing bonuses must not apply again to stored Burn or
Poison. Ticks, detonations and consumed Poison now use resolved damage operations,
retaining current recipient defenses. Explicit non-damaging stack grants and
reflections retain their specified potency. Bleed and authored recurring damage
keep their separate existing behavior. Canonical rules live in
[Damage and effect contracts](../AgentContext/battle-damage.md).

Repeated attacks also use their own actual Health damage and cannot attach stacks
after a dodge. No stacks attach to a target whose Health was protected by a fatal
redirect. Redirection itself remains its existing reaction, rather than a new
status-applying attack.

### Combustion

Approved exact wording: “Deal 6 Burn damage. Detonate all enemy Burn at once.”
Keep the existing resolution order and condition: the damage and fresh Burn
resolve before detonation, so fresh Burn is still included. The universal damage
rule changes its numbers consistently with all other Burn abilities; this copy
change introduces no separate Combustion behavior change.

### Enemy passive candidates

Keep the existing elemental vulnerabilities unless separately selected for change.
These are enemy identity traits, not changes to shared ability semantics.

- Giant Spider currently says “Attacks apply 1 Poison,” but the engine grants the
  extra stack only on basic attack hits. Recommended replacement: “The first time
  each battle the Giant Spider damages your Health, apply 1 Poison.” This retains
  a venomous opening, requires penetration, and removes recurring extra buildup.
  Alternative: “While you are Poisoned, the Giant Spider takes 1 less Physical
  damage from your attacks” for a patient predator identity; this risks longer fights.
- Pyromancer currently ignores all Block and damage reduction with Burn.
  Recommended replacement: “Every third turn, prepare +1 Burn damage for its next
  Burn attack.” This uses a visible, bounded fire buildup while restoring Block
  counterplay. Specify preparation timing and consume it once on the next Burn
  attack; it must not independently amplify every tick. Alternative: “The first
  Burn attack each battle deals +1 damage” for a simpler, less sustained threat.
  Compare both against Kindling's existing next-Burn bonus before choosing numbers.

The Giant Spider's proposed explicit +1 Poison is a non-damaging rider, conditional
on Health damage. Confirm whether the user wants such named extras to remain or
wants strictly one stack per Health damage with no additive riders anywhere.

### Additional passive ideas

Numbers are starting proposals, not verified balance targets. Preserve existing
vulnerabilities unless separately approved.

| Enemy | Candidate | Behavior and tradeoff |
| --- | --- | --- |
| Giant Spider | Silk Carapace | Starts combat with 3 Block. Simple defensive identity without extra Poison. |
| Giant Spider | Skitter Back | Gains 1 Block after its Basic attack. Sustained defense; may lengthen fights. |
| Giant Spider | Fresh Venom | Its Poison attacks deal +1 damage against targets that are not yet Poisoned. Rewards initial contact instead of compounding an existing stack; normal Block applies. |
| Pyromancer | Cinder Shield | The first time each battle it applies Burn, gain 3 Block. One visible defensive reward; no extra ongoing damage. |
| Pyromancer | Overheat | Its Burn Skill deals +1 damage and costs it 2 Health. Stronger fire with a predictable self-damage cost. |
| Pyromancer | Smoldering Focus | If it lost no Health during the previous round, prepare +1 damage for its next Burn attack, replacing rather than accumulating the preparation. Encourages aggression; check interaction with Kindling's bonus. |

## Plan

- [x] Record accepted universal rules and exact Combustion wording.
- [x] Implement Health-damage stack application and resolved Burn/Poison ticks.
- [x] Preserve explicit stack grants, reflection, decay/tick-count talents and Bleed.
- [x] Correct repeated attack attachments and update canonical damage rules.
- [x] Regenerate content and verify generation is idempotent.
- [x] Add regression coverage for both sides, partial/full Block, flat/percent and
  critical bonuses, mitigation, damaging effects/reactions, repeated attacks,
  ticks, detonations and fresh-Burn Combustion.
- [x] Review final diff and complete available static checks. Final simulator rerun
  intentionally skipped at the user's request; do not claim full verification.
- [ ] Select enemy passive changes with the user before implementing them.
- [ ] Archive this plan when the retained passive discussion and implementation finish.

## Verification notes

- Generation and idempotence passed; generated ability inventory contains the exact
  requested Combustion wording. Other pre-existing generated roster changes belong
  to unrelated in-flight work and were preserved.
- Scoped SwiftFormat, SwiftLint and style guardrails passed for all 16 changed Swift
  files. Module boundaries, release-note validation and artwork budgets passed.
- TrinketContent passed all 244 tests. Removed its incidental old-copy assertion;
  Combustion's behavior assertions remain.
- Initial BattleEngine run: 658 passed, 7 failed. New application tests passed;
  failures asserted the old stack/tick rules. Updated those expectations with the
  approved damage contract, made Unstable Culture's test independent of incidental
  critical hits, and retired the duplicate Flashover tick test in favor of the
  combined initial-hit/tick coverage in DoTMechanicsTests.
- Final BattleEngine rerun was interrupted at the user's explicit request to wrap
  up without simulator verification. The final test updates and newly added
  detonation/Combustion cases have not been verified by a completed rerun.
- Full scoped handoff was attempted and blocked by the pre-existing documentation
  gate: Scripts/Reference.md lacks the Scripts/playthrough-sweep.sh command entry.
  That unrelated in-flight work was not modified.
- No full balance simulation and no claim of verified passive balance.

Retain this active plan intentionally for the unselected passive proposals.
When complete, record the outcome in `Docs/Plans/Archived/README.md` and delete it.
