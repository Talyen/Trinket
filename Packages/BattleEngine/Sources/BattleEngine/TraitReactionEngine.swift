import Foundation
import TrinketContent
import TrinketCore

/// Applies combatant trait reactions that fire alongside heals, cleanses, and gold gains.
package enum TraitReactionEngine {
    package static func healAfterCleanse(
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseBonusHeal,
            source: source,
            target: target,
            in: &context
        )
    }

    package static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf,
            source: source,
            target: source,
            in: &context
        )
    }

    package static func healHeroAfterRestore(
        source: Combatant,
        hero: Combatant,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard source.id != hero.id else { return .empty }
        return resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.restoreHealthAlsoHealHero,
            source: source,
            target: hero,
            in: &context,
            suppressTraitReactions: true
        )
    }

    private static func resolveBonusHeal(
        amount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext,
        suppressTraitReactions: Bool = false
    ) -> CombatOutcome {
        guard amount > 0 else { return .empty }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: source.traitDisplayName(in: context),
                    keyword: .health,
                    displayAmount: amount
                ),
                suppressTraitReactions: suppressTraitReactions
            ),
            in: &context
        )
    }
}

private extension Combatant {
    func traitDisplayName(in context: BattleEngineContext) -> String {
        context.modifiers(for: id).traitDisplayName ?? "Trait"
    }
}
