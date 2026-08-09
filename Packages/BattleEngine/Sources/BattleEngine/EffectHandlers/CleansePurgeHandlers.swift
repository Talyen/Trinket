import Foundation
import TrinketContent
import TrinketCore

/// Shared handler for targeted/random cleanse (debuff removal) and purge (buff removal).
struct CleansePurgeHandler: BattleEffectHandler {
    enum Mode: Sendable {
        case cleanse
        case cleanseRandom
        case purge
        case purgeRandom

        var kind: EffectKind {
            switch self {
            case .cleanse: .cleanse
            case .cleanseRandom: .cleanseRandom
            case .purge: .purge
            case .purgeRandom: .purgeRandom
            }
        }

        var appliedEffectKind: ActionEvent.EffectKind {
            switch self {
            case .cleanse, .cleanseRandom: .cleanseApplied
            case .purge, .purgeRandom: .purgeApplied
            }
        }

        var healsAfterRemoval: Bool {
            switch self {
            case .cleanse, .cleanseRandom: true
            case .purge, .purgeRandom: false
            }
        }
    }

    let mode: Mode
    var kind: EffectKind {
        mode.kind
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        var currentEffects = context.roster.activeEffects(for: target)
        let removedKeyword: Keyword?
        switch mode {
        case .cleanse:
            guard case let .cleanse(targetKeyword) = effect else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            guard EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword) else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            removedKeyword = targetKeyword ?? .health
        case .cleanseRandom:
            removedKeyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng)
        case .purge:
            guard case let .purge(targetKeyword) = effect else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            guard EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword) else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            removedKeyword = targetKeyword ?? .purge
        case .purgeRandom:
            removedKeyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng)
        }

        guard let removedKeyword else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(currentEffects, for: target)

        let event = context.nextEvent(
            kind: .effect,
            effectKind: mode.appliedEffectKind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: removedKeyword
        )
        var events = [event]
        if mode.healsAfterRemoval {
            events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(
                source: source,
                target: target,
                in: &context
            ).events)
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
