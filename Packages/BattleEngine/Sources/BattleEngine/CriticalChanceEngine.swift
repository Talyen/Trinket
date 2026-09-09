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
        usePartyMaximum: Bool = false,
        in context: inout BattleState,
    ) -> Bool {
        var chance = chance(
            actorID: actorID, defender: defender, abilityBonus: abilityBonus,
            countsBleedingDefender: countsBleedingDefender, in: context,
        )
        if usePartyMaximum, let actor = context.roster.combatant(for: actorID), actor.role != .enemy {
            for owner in [BattleParticipant.hero, .companion] where context.roster[owner].isAlive {
                chance = max(chance, Self.chance(actorID: context.roster[owner].id, defender: defender, in: context))
            }
        }
        return BattleChance.succeeds(probability: chance, using: &context.rng)
    }

    static func chance(
        actorID: String,
        defender: Combatant,
        abilityBonus: Double = 0,
        countsBleedingDefender: Bool = false,
        in context: BattleState,
    ) -> Double {
        guard let actor = context.roster.combatant(for: actorID) else { return 0 }
        if actor.role == .enemy {
            return 0
        }
        var chance = 0.10
        chance += abilityBonus
        chance += context.modifiers(for: actorID).triggers.criticalChanceBonus
        chance += partyCritChanceBonus(actorRole: actor.role, in: context)
        if context.modifiers(for: actorID).triggers.killingGrace {
            chance += DamagePipeline.dodgeChance(for: actor.combatant, attackerID: context.roster.enemy.id, in: context)
        }
        if countsBleedingDefender,
           context.roster.activeEffects(for: defender).contains(where: { $0.effect.keyword == .bleed }) {
            chance += context.modifiers(for: actorID).triggers.critChancePerBleedingEnemy
        }
        for active in context.roster.activeEffects(for: actor.combatant) {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }
        return min(0.75, max(0, chance))
    }

    private static func partyCritChanceBonus(
        actorRole: Combatant.Role,
        in context: borrowing BattleState,
    ) -> Double {
        guard actorRole != .enemy, context.roster.companion.isAlive else { return 0 }
        let companionTriggers = context.companionModifiers.triggers
        var bonus: Double = 0
        let companionMaxHealth = context.roster.companion.maxHealth
        if companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold > 0,
           companionMaxHealth > 0,
           Double(context.roster.companion.currentHealth) / Double(companionMaxHealth)
           > companionTriggers.partyCritChanceWhileCompanionAboveHealthThreshold {
            bonus += companionTriggers.partyCritChanceWhileCompanionAboveHealthBonus
        }
        if actorRole == .hero, companionTriggers.heroCritChanceWhileCompanionAlive > 0 {
            bonus += companionTriggers.heroCritChanceWhileCompanionAlive
        }
        if companionTriggers.partyCritChanceWhileGoldAbove > 0,
           context.gold >= companionTriggers.partyCritChanceWhileGoldAbove {
            bonus += companionTriggers.partyCritChanceWhileGoldAboveBonus
        }
        return bonus
    }
}
