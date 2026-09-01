import Foundation
import TrinketContent
import TrinketCore

package enum CriticalChanceEngine {
    package static func rollSucceeds(
        keyword _: Keyword,
        actorID: String,
        defender: Combatant,
        abilityBonus: Double = 0,
        countsBleedingDefender: Bool = false,
        in context: inout BattleState,
    ) -> Bool {
        guard let actor = context.roster.combatant(for: actorID) else { return false }
        if actor.role == .enemy {
            return false
        }
        var chance = 0.10
        chance += abilityBonus
        chance += context.modifiers(for: actorID).triggers.criticalChanceBonus
        chance += partyCritChanceBonus(actor: actor, in: context)
        if countsBleedingDefender,
           context.roster.activeEffects(for: defender).contains(where: { $0.effect.keyword == .bleed }) {
            chance += context.modifiers(for: actorID).triggers.critChancePerBleedingEnemy
        }
        for active in context.roster.activeEffects(for: actor.combatant) {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }
        chance = min(0.75, max(0, chance))
        return BattleChance.succeeds(probability: chance, using: &context.rng)
    }

    private static func partyCritChanceBonus(
        actor: CombatantRuntime,
        in context: BattleState,
    ) -> Double {
        guard actor.role != .enemy, context.roster.companion.isAlive else { return 0 }
        let companionTriggers = context.companionModifiers.triggers
        var bonus: Double = 0
        if companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold > 0,
           context.roster.maxHealth(for: context.roster.companion.combatant) > 0,
           Double(context.roster.health(for: context.roster.companion.combatant))
           / Double(context.roster.maxHealth(for: context.roster.companion.combatant))
           >= companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold {
            bonus += companionTriggers.partyCritChanceWhileCompanionAboveHealthBonus
        }
        if actor.role == .hero, companionTriggers.heroCritChanceWhileCompanionAlive > 0 {
            bonus += companionTriggers.heroCritChanceWhileCompanionAlive
        }
        if companionTriggers.partyCritChanceWhileGoldAbove > 0,
           context.gold >= companionTriggers.partyCritChanceWhileGoldAbove {
            bonus += companionTriggers.partyCritChanceWhileGoldAboveBonus
        }
        return bonus
    }
}
