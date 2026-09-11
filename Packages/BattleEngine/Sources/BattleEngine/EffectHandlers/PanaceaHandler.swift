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
        let action = BattleActionContext(actor: source, in: context)
        let cleanseTarget = BattleActionContext.mostDebuffed(in: action.allies(in: context), state: context)
        return CleanseOperation.resolve(
            .all(nil), source: source, target: cleanseTarget, abilityName: ability.name,
            baseHeal: baseHeal, healPerDebuff: healPerDebuff,
            healTarget: action.target(.lowestHealthAlly, in: context), origin: .direct, in: &context,
        ).application
    }
}
