import Foundation
import TrinketContent
import TrinketCore

struct CleansePurgeHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome {
        switch effect {
        case let .cleanse(keyword):
            await EffectRemovalOperation.resolveCleanse(
                .all(keyword), source: source, target: target, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case let .cleanseHealPerDebuff(healPerDebuff):
            await EffectRemovalOperation.resolveCleanse(
                .all(nil), source: source, target: target, abilityName: ability.name,
                healPerDebuff: healPerDebuff, origin: .direct, in: &context,
            ).application
        case .cleanseRandom:
            await EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: source, target: target, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case let .purge(keyword):
            await EffectRemovalOperation.resolvePurge(
                .all(keyword), source: source, target: target, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        case .purgeRandom:
            await EffectRemovalOperation.resolvePurge(
                .randomBuffs(1), source: source, target: target, abilityName: ability.name,
                origin: .direct, in: &context,
            ).application
        default:
            EffectApplyOutcome(events: [], didApply: false)
        }
    }
}

struct PanaceaHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target _: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome {
        guard case let .panacea(baseHeal, healPerDebuff) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let action = BattleActionContext(actor: source, in: context)
        let cleanseTarget = BattleActionContext.mostDebuffed(in: action.allies(in: context), state: context)
        return await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: source, target: cleanseTarget, abilityName: ability.name,
            baseHeal: baseHeal, healPerDebuff: healPerDebuff,
            healTarget: .lowestHealthAlly, origin: .direct, in: &context,
        ).application
    }
}
