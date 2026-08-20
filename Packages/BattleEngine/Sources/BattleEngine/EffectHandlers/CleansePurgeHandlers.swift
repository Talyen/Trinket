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
        let beforeCount = currentEffects.count
        guard let removal = removeMatching(
            effect,
            from: &currentEffects,
            rng: &context.rng
        ) else {
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
            keyword: removal.keyword
        )
        var events = [event]
        if mode.healsAfterRemoval {
            events.append(contentsOf: appendCleanseFollowUps(
                source: source,
                target: target,
                abilityName: ability.name,
                removedKeyword: removal.keyword,
                removedCount: beforeCount - currentEffects.count,
                healPerRemoved: removal.healPerRemoved,
                in: &context
            ))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private struct Removal {
        var keyword: Keyword
        var healPerRemoved: Int
    }

    private func removeMatching(
        _ effect: Effect,
        from currentEffects: inout [ActiveEffect],
        rng: inout SeededRandomNumberGenerator
    ) -> Removal? {
        switch mode {
        case .cleanse:
            switch effect {
            case let .cleanse(targetKeyword):
                guard EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword) else {
                    return nil
                }
                return Removal(keyword: targetKeyword ?? .health, healPerRemoved: 0)
            case let .cleanseHealPerDebuff(healPer):
                guard EffectRemoval.removeDebuffs(from: &currentEffects, keyword: nil) else {
                    return nil
                }
                return Removal(keyword: .health, healPerRemoved: healPer)
            default:
                return nil
            }
        case .cleanseRandom:
            guard let keyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &rng) else {
                return nil
            }
            return Removal(keyword: keyword, healPerRemoved: 0)
        case .purge:
            guard case let .purge(targetKeyword) = effect else { return nil }
            guard EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword) else {
                return nil
            }
            return Removal(keyword: targetKeyword ?? .purge, healPerRemoved: 0)
        case .purgeRandom:
            guard let keyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &rng) else {
                return nil
            }
            return Removal(keyword: keyword, healPerRemoved: 0)
        }
    }

    private func appendCleanseFollowUps(
        source: Combatant,
        target: Combatant,
        abilityName: String,
        removedKeyword: Keyword,
        removedCount: Int,
        healPerRemoved: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if healPerRemoved > 0, removedCount > 0 {
            let amount = healPerRemoved * removedCount
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: amount,
                    target: target,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: abilityName,
                        keyword: .health,
                        displayAmount: amount
                    )
                ),
                in: &context
            ).events)
        }
        events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(
            source: source,
            target: target,
            in: &context
        ).events)
        events.append(contentsOf: CombatTriggerEngine.healWearerAfterCleanse(
            source: source,
            in: &context
        ).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(
            source: source,
            in: &context
        ))
        events.append(contentsOf: CombatTriggerEngine.afterCleansePerformed(
            source: source,
            target: target,
            removedKeyword: removedKeyword,
            removedCount: removedCount,
            in: &context
        ))
        return events
    }
}
