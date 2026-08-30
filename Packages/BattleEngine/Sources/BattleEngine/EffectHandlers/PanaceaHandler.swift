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
        let beforeCount = cleanseEffects.count
        guard EffectRemoval.removeDebuffs(from: &cleanseEffects, keyword: nil) else {
            var events: [ActionEvent] = []
            let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: context)
            events.append(contentsOf: context.healEmitting(
                amount: baseHeal,
                target: healTarget,
                source: source,
                abilityName: ability.name,
            ))
            return EffectApplyOutcome(events: events, didApply: true)
        }
        context.roster.setActiveEffects(cleanseEffects, for: cleanseTarget)
        let removedCount = beforeCount - cleanseEffects.count
        let healAmount = baseHeal + healPerDebuff * removedCount
        let healTarget = BattleConditionEvaluator.lowestHealthAlly(in: context)
        var events: [ActionEvent] = []
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: cleanseTarget,
            amount: 0,
            keyword: .health,
        ))
        events.append(contentsOf: context.healEmitting(
            amount: healAmount,
            target: healTarget,
            source: source,
            abilityName: ability.name,
        ))
        events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(
            source: source,
            target: cleanseTarget,
            in: &context,
        ).events)
        events.append(contentsOf: CombatTriggerEngine.healWearerAfterCleanse(
            source: source,
            in: &context,
        ).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(
            source: source,
            in: &context,
        ))
        events.append(contentsOf: CombatTriggerEngine.afterCleansePerformed(
            source: source,
            target: cleanseTarget,
            removedKeyword: .health,
            removedCount: removedCount,
            in: &context,
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
