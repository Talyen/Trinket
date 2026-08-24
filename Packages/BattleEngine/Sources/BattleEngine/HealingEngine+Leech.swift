import Foundation
import TrinketContent
import TrinketCore

package extension HealingEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        target: Combatant? = nil,
        blockedAmount: Int = 0,
        abilityHasLeech: Bool = false,
        damageKeyword: Keyword? = nil,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard damage > 0,
              let actor = context.roster.combatant(for: sourceActorID),
              context.roster.health(for: actor.combatant) > 0
        else { return .empty }
        let actorCombatant = actor.combatant

        let profile = context.modifiers(for: sourceActorID)
        // Vampiric Touch: Leech heals based on the blocked portion too.
        var baseDamage = damage
        if profile.triggers.leechOnBlockDamage, blockedAmount > 0 {
            baseDamage += blockedAmount
        }

        var leechPct = 0.0
        if abilityHasLeech {
            leechPct = Effect.abilityLeechPercent
        }
        let buffPct = context.roster.activeEffects(for: actorCombatant).reduce(0.0) { maxPercent, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect {
                return max(maxPercent, percent)
            }
            return maxPercent
        }
        leechPct = max(leechPct, buffPct)
        let keywordGrantsLeech = damageKeyword == .freeze && profile.triggers.freezeDamageLeech
            || damageKeyword == .poison && profile.triggers.poisonDamageLeech
            || damageKeyword == .burn && profile.triggers.burnDamageLeech
            || damageKeyword == .bleed && profile.triggers.bleedDamageLeech
        if leechPct == 0, keywordGrantsLeech {
            leechPct = Effect.abilityLeechPercent
        }
        if leechPct == 0,
           BattleChance.succeeds(probability: profile.triggers.leechChancePercent, using: &context.rng) {
            leechPct = Effect.abilityLeechPercent
        }
        guard leechPct > 0 else { return .empty }
        leechPct += profile.leechGainedBonus

        // Blood Hunger: +2% Leech against below-half-Health enemies.
        if let target, profile.triggers.leechPercentVsLowHealthEnemies > 0,
           context.roster.maxHealth(for: target) > 0,
           Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target)) < 0.5 {
            leechPct += profile.triggers.leechPercentVsLowHealthEnemies
        }

        var restored = CombatRounding.scaled(baseDamage, multiplier: leechPct)
        restored += profile.leechHealingBonus
        restored = CombatRounding.scaled(
            restored,
            multiplier: CombatTriggerEngine.incomingHealMultiplier(for: actorCombatant, in: context)
        )
        // Grave Harvest: bonus Leech heal against below-half-Health enemies.
        if let target, profile.triggers.leechBonusHealVsLowHealthEnemies > 0,
           context.roster.maxHealth(for: target) > 0,
           Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target)) < 0.5 {
            restored += profile.triggers.leechBonusHealVsLowHealthEnemies
        }
        // Frenzied Feeding / Affliction Siphon: double Leech vs Poisoned or Bleeding targets.
        if let target, profile.triggers.leechHealingVsAfflictedMultiplier > 1 {
            let afflicted = context.roster.activeEffects(for: target).contains {
                $0.effect.keyword == .poison || $0.effect.keyword == .bleed
            }
            if afflicted {
                restored = CombatRounding.scaled(restored, multiplier: profile.triggers.leechHealingVsAfflictedMultiplier)
            }
        }
        guard restored > 0 else { return .empty }

        var events: [ActionEvent] = []
        var actualRestored = 0
        var leechFlags = Set<CombatFlag>()
        // Blood Link: Leech overheal transfers to the Companion.
        if actorCombatant.role == .hero,
           context.roster.companion.isAlive,
           profile.triggers.leechOverhealTransfersToCompanion,
           context.roster.health(for: actorCombatant) >= context.roster.maxHealth(for: actorCombatant) {
            let healOutcome = resolveHeal(
                HealRequest(
                    amount: restored,
                    target: context.roster.companion.combatant,
                    sourceActorID: sourceActorID,
                    logAs: .leech
                ),
                in: &context
            )
            guard healOutcome.healthRestored > 0 else { return .empty }
            actualRestored = healOutcome.healthRestored
            leechFlags = healOutcome.flags
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: context.roster.companion.combatant,
                amount: actualRestored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil,
                isCritical: healOutcome.isCritical
            ))
        } else {
            let healOutcome = resolveHeal(
                HealRequest(
                    amount: restored,
                    target: actorCombatant,
                    sourceActorID: sourceActorID,
                    logAs: .leech
                ),
                in: &context
            )
            guard healOutcome.healthRestored > 0 else { return .empty }
            actualRestored = healOutcome.healthRestored
            leechFlags = healOutcome.flags
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: actorCombatant,
                amount: actualRestored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil,
                isCritical: healOutcome.isCritical
            ))
            // Symbiosis affix: the Hero's Leech healing is shared with the Companion.
            if actorCombatant.id == context.roster.hero.id {
                events.append(contentsOf: CombatTriggerEngine.shareHeroLeechWithCompanion(
                    restored: actualRestored,
                    in: &context
                ))
            }
            // Shared Feast: the Companion shares its Leech healing with the Hero.
            if actorCombatant.role == .companion, context.roster.hero.isAlive,
               profile.triggers.leechSharesToHeroPercent > 0 {
                let share = CombatRounding.scaled(
                    actualRestored,
                    multiplier: min(1, max(0, profile.triggers.leechSharesToHeroPercent))
                )
                if share > 0 {
                    events.append(contentsOf: Self.resolveHeal(
                        HealRequest(amount: share, target: context.roster.hero.combatant, sourceActorID: sourceActorID),
                        in: &context
                    ).events)
                }
            }
            // Vitality Infusion: Companion Leech restores Hero Mana.
            if actorCombatant.role == .companion, context.roster.hero.isAlive,
               profile.triggers.onCompanionLeechRestoreHeroMana > 0 {
                events.append(contentsOf: context.restoreManaEmitting(
                    profile.triggers.onCompanionLeechRestoreHeroMana,
                    to: context.roster.hero.combatant,
                    abilityName: "Vitality Infusion"
                ))
            }
        }
        events.append(contentsOf: CombatTriggerEngine.afterLeech(by: actorCombatant, target: target, in: &context))
        var flags = leechFlags
        flags.insert(.leeched)
        return CombatOutcome(healthDelta: actualRestored, events: events, flags: flags)
    }
}
