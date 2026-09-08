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
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTurnOrder {
            let combatant = context.roster[participant].combatant
            guard context.roster[participant].isAlive else { continue }

            let result = advanceEffects(
                context.roster.activeEffects(for: combatant),
                target: combatant,
                context: &context,
            )
            context.roster.setActiveEffects(result.updated, for: combatant)
            events.append(contentsOf: result.events)
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
    ) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        for scheduledEffect in effects {
            guard context.roster.health(for: target) > 0 else { break }
            guard let activeEffect = context.roster.activeEffects(for: target).first(where: { $0.id == scheduledEffect.id })
            else { continue }
            guard let handler = EffectHandlers.all[activeEffect.effect.kind] else {
                logger.error(
                    "Missing effect handler for turn of \(String(describing: activeEffect.effect.kind), privacy: .public)",
                )
                continue
            }
            let outcome = handler.advanceTurn(activeEffect, on: target, in: &context)
            events.append(contentsOf: outcome.events)
            var currentEffects = context.roster.activeEffects(for: target)
            guard let index = currentEffects.firstIndex(where: { $0.id == activeEffect.id }) else { continue }
            if outcome.removeAfter {
                currentEffects.remove(at: index)
            } else if let updated = outcome.updatedStack {
                currentEffects[index].remainingTurns = updated.remainingTurns
                if currentEffects[index].sourceActorID == activeEffect.sourceActorID {
                    currentEffects[index].sourceActorID = updated.sourceActorID
                }
                if currentEffects[index].effect == activeEffect.effect {
                    currentEffects[index].effect = updated.effect
                }
            }
            context.roster.setActiveEffects(currentEffects, for: target)
        }
        return (events, context.roster.activeEffects(for: target))
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
