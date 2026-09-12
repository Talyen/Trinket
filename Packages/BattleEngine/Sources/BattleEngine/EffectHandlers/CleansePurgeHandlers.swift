import Foundation
import TrinketContent
import TrinketCore

struct CleansePurgeHandler: BattleEffectHandler {
    enum Mode {
        case cleanse
        case cleanseRandom
        case purge
        case purgeRandom
    }

    let mode: Mode
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        switch mode {
        case .cleanse:
            applyCleanse(effect, ability: ability, source: source, target: target, in: &context)
        case .cleanseRandom:
            applyCleanseRandom(ability: ability, source: source, target: target, in: &context)
        case .purge:
            applyPurge(effect, ability: ability, source: source, target: target, in: &context)
        case .purgeRandom:
            applyPurgeRandom(ability: ability, source: source, target: target, in: &context)
        }
    }

    private func applyCleanse(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        let targetKeyword: Keyword?
        let healPerDebuff: Int
        switch effect {
        case let .cleanse(keyword):
            targetKeyword = keyword
            healPerDebuff = 0
        case let .cleanseHealPerDebuff(healPer):
            targetKeyword = nil
            healPerDebuff = healPer
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return CleanseOperation.resolve(
            .all(targetKeyword), source: source, target: target, abilityName: ability.name,
            healPerDebuff: healPerDebuff, origin: .direct, in: &context,
        ).application
    }

    private func applyCleanseRandom(
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        CleanseOperation.resolve(.random, source: source, target: target, abilityName: ability.name, origin: .direct, in: &context)
            .application
    }

    private func applyPurge(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .purge(keyword) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return PurgeOperation.resolve(
            .all(keyword), source: source, target: target, abilityName: ability.name, origin: .direct, in: &context,
        ).application
    }

    private func applyPurgeRandom(
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        PurgeOperation.resolve(
            .randomBuffs(1), source: source, target: target, abilityName: ability.name, origin: .direct, in: &context,
        ).application
    }
}
