import Foundation
import TrinketCore
import TrinketContent

/// Applies combatant trait reactions that fire alongside heals, cleanses, and gold gains.
package enum TraitReactionEngine {
    package static func healAfterCleanse(
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        let amount = context.modifiers(for: source.id).cleanseBonusHeal
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: source.traitDisplayName,
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        )
    }

    package static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        let amount = context.modifiers(for: source.id).gainGoldBonusHealSelf
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: source,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: source.traitDisplayName,
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        )
    }

    package static func healHeroAfterRestore(
        source: Combatant,
        hero: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        let amount = context.modifiers(for: source.id).restoreHealthAlsoHealHero
        guard amount > 0, source.id != hero.id else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: hero,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: source.traitDisplayName,
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        )
    }
}

private extension Combatant {
    var traitDisplayName: String {
        GameContent.trait(forCombatantID: id)?.name ?? "Trait"
    }
}
