import Foundation
import TrinketContent
import TrinketCore

package enum EffectTurnEngine {
    package static func advanceAll(context: inout BattleState) -> [ActionEvent] {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTurnOrder {
            guard !context.isBattleOver else { break }
            let combatant = context.roster[participant].combatant
            guard context.roster[participant].isAlive else { continue }

            events.append(contentsOf: advanceEffects(
                on: combatant,
                context: &context,
            ))
            guard !context.isBattleOver else { break }
            events.append(contentsOf: CombatTriggerEngine.turnBlock(for: combatant, in: &context))
            events.append(contentsOf: EnemyTraitEngine.turnFreeze(for: combatant, context: &context))
            events.append(contentsOf: EnemyTraitEngine.turnRandomDamageAllEnemies(for: combatant, context: &context))
            if participant != .enemy,
               context.roster[participant].isAlive,
               CombatTriggerEngine.partyDebuffsExpireFaster(in: context) {
                context.roster.setActiveEffects(
                    accelerateDebuffExpiration(context.roster.activeEffects(for: combatant)),
                    for: combatant,
                )
            }
        }

        return events
    }

    package static func advanceEffects(
        on target: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        // Keep the original schedule without retaining the array handlers mutate.
        let scheduledEffectIDs = context.roster.activeEffects(for: target).map(\.id)
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        let wasAdvancingEffects = context.resolution.isAdvancingEffects
        context.resolution.isAdvancingEffects = true
        defer {
            context.resolution.feedbackGroupID = previousFeedbackGroup
            context.resolution.isAdvancingEffects = wasAdvancingEffects
        }
        var events: [ActionEvent] = []
        for effectID in scheduledEffectIDs {
            guard !context.isBattleOver, context.roster.health(for: target) > 0 else { break }
            guard let activeEffect = context.roster.activeEffects(for: target).first(where: { $0.id == effectID })
            else { continue }
            let handler = EffectHandlers.handler(for: activeEffect.effect.kind)
            let outcome = handler.advanceTurn(activeEffect, on: target, in: &context)
            events.append(contentsOf: outcome)
        }
        return events
    }

    private static func accelerateDebuffExpiration(_ effects: [ActiveEffect]) -> [ActiveEffect] {
        effects.compactMap { active in
            guard active.effect.isRemovableDebuff else { return active }
            guard !active.effect.isDecayingDoT else { return active }
            guard active.remainingTurns > 0 else { return active }
            var updated = active
            updated.remainingTurns -= 1
            return updated.remainingTurns > 0 ? updated : nil
        }
    }
}
