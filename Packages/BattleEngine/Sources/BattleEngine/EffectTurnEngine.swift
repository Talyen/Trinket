import Foundation
import TrinketContent
import TrinketCore

package enum EffectTurnEngine {
    package static func advanceAll(context: inout BattleState) async {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }

        for participant in BattleParticipant.effectTurnOrder {
            guard !context.isBattleOver else { break }
            let combatant = context.roster[participant].combatant
            guard context.roster[participant].isAlive else { continue }

            await advanceEffects(on: combatant, context: &context)
            guard !context.isBattleOver else { break }
            CombatTriggerEngine.turnBlock(for: combatant, in: &context)
            await EnemyTraitEngine.turnFreeze(for: combatant, context: &context)
            await EnemyTraitEngine.turnRandomDamageAllEnemies(for: combatant, context: &context)
            if participant != .enemy,
               context.roster[participant].isAlive,
               CombatTriggerEngine.partyDebuffsExpireFaster(in: context) {
                context.roster.setActiveEffects(
                    accelerateDebuffExpiration(context.roster.activeEffects(for: combatant)),
                    for: combatant,
                )
            }
        }
    }

    package static func advanceEffects(
        on target: Combatant,
        context: inout BattleState,
    ) async {
        // Keep the original schedule without retaining the array handlers mutate.
        let scheduledEffectIDs = context.roster.activeEffects(for: target).map(\.id)
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        let wasAdvancingEffects = context.resolution.isAdvancingEffects
        context.resolution.isAdvancingEffects = true
        defer {
            context.resolution.feedbackGroupID = previousFeedbackGroup
            context.resolution.isAdvancingEffects = wasAdvancingEffects
        }

        for effectID in scheduledEffectIDs {
            guard !context.isBattleOver, context.roster.health(for: target) > 0 else { break }
            guard let activeEffect = context.roster.activeEffects(for: target).first(where: { $0.id == effectID })
            else { continue }
            let handler = EffectHandlers.handler(for: activeEffect.effect.kind)
            await handler.advanceTurn(activeEffect, on: target, in: &context)
        }
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
