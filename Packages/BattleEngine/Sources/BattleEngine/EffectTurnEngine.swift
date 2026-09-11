import Foundation
import os
import TrinketContent
import TrinketCore

package enum EffectTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "EffectTurnEngine",
    )

    package static func advanceAll(context: inout BattleState) -> [ActionEvent] {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        defer { context.resolution.feedbackGroupID = previousFeedbackGroup }
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTurnOrder {
            guard !context.isBattleOver else { break }
            let combatant = context.roster[participant].combatant
            guard context.roster[participant].isAlive else { continue }

            events.append(contentsOf: advanceEffects(
                context.roster.activeEffects(for: combatant),
                target: combatant,
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
        _ effects: [ActiveEffect],
        target: Combatant,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let previousFeedbackGroup = context.resolution.beginFeedbackGroup(eventID: context.nextEventID + 1)
        let wasAdvancingEffects = context.resolution.isAdvancingEffects
        context.resolution.isAdvancingEffects = true
        defer {
            context.resolution.feedbackGroupID = previousFeedbackGroup
            context.resolution.isAdvancingEffects = wasAdvancingEffects
        }
        var events: [ActionEvent] = []
        for scheduledEffect in effects {
            guard !context.isBattleOver, context.roster.health(for: target) > 0 else { break }
            guard let activeEffect = context.roster.activeEffects(for: target).first(where: { $0.id == scheduledEffect.id })
            else { continue }
            guard let handler = EffectHandlers.all[activeEffect.effect.kind] else {
                logger.error(
                    "Missing effect handler for turn of \(String(describing: activeEffect.effect.kind), privacy: .public)",
                )
                continue
            }
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
