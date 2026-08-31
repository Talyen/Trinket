import Foundation
import TrinketContent
import TrinketCore

struct PanaceaHandler: BattleEffectHandler {
    let kind: EffectKind = .panacea

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target _: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .panacea(baseHeal, healPerDebuff) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let cleanseTarget = BattleConditionEvaluator.mostDebuffedAlly(in: context)
        var cleanseEffects = context.roster.activeEffects(for: cleanseTarget)
        let removedDebuffs = EffectRemoval.removeDebuffs(from: &cleanseEffects, keyword: nil)
        guard !removedDebuffs.isEmpty else {
            let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: context)
            return EffectApplyOutcome(
                events: context.healEmitting(
                    amount: baseHeal,
                    target: healTarget,
                    source: source,
                    abilityName: ability.name,
                ),
                didApply: true,
            )
        }
        context.roster.setActiveEffects(cleanseEffects, for: cleanseTarget)
        let healAmount = baseHeal + healPerDebuff * removedDebuffs.count
        let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: context)
        let events = CleanseEventBuilder.events(
            removed: removedDebuffs,
            abilityName: ability.name,
            source: source,
            target: cleanseTarget,
            healAmount: healAmount,
            healTarget: healTarget,
            in: &context,
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
