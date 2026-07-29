import Foundation
import os
import TrinketContent
import TrinketCore

public enum EffectTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "EffectTurnEngine"
    )

    public static func advanceAll(context: inout BattleState, matchup: BattleMatchup) -> [ActionEvent] {
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTurnOrder {
            let combatant = matchup.combatant(for: participant)
            if participant != .enemy {
                guard context.roster[participant].isAlive else { continue }
            }

            let result = advanceEffects(
                context.roster.activeEffects(for: combatant),
                target: combatant,
                context: &context
            )
            context.roster.setActiveEffects(result.updated, for: combatant)
            events.append(contentsOf: result.events)
            events.append(contentsOf: EnemyTraitEngine.turnRegeneration(for: combatant, context: &context))
            events.append(contentsOf: EnemyTraitEngine.turnBlock(for: combatant, context: &context))
            events.append(contentsOf: EnemyTraitEngine.turnFreeze(for: combatant, context: &context))
        }

        return events
    }

    public static func advanceEffects(
        _ effects: [ActiveEffect],
        target: Combatant,
        context: inout BattleState
    ) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var turnOutcomes: [Int: (updatedStack: ActiveEffect?, removeAfter: Bool)] = [:]

        guard context.roster.health(for: target) > 0 else {
            return (events, effects)
        }

        for activeEffect in effects {
            guard context.roster.health(for: target) > 0 else { break }
            guard let handler = EffectHandlers.all[activeEffect.effect.kind] else {
                logger.error(
                    "Missing effect handler for turn of \(String(describing: activeEffect.effect.kind), privacy: .public)"
                )
                continue
            }
            let outcome = handler.advanceTurn(activeEffect, on: target, in: &context)
            events.append(contentsOf: outcome.events)
            turnOutcomes[activeEffect.id] = (outcome.updatedStack, outcome.removeAfter)
        }

        var merged = context.roster.activeEffects(for: target)
        if !turnOutcomes.isEmpty {
            merged = merged.compactMap { activeEffect in
                guard let outcome = turnOutcomes[activeEffect.id] else { return activeEffect }
                if outcome.removeAfter {
                    return nil
                }
                if let updated = outcome.updatedStack {
                    var preserved = activeEffect
                    preserved.remainingTurns = updated.remainingTurns
                    preserved.sourceActorID = updated.sourceActorID
                    if activeEffect.effect.kind == updated.effect.kind,
                       activeEffect.effect == effects.first(where: { $0.id == activeEffect.id })?.effect {
                        preserved.effect = updated.effect
                    }
                    return preserved
                }
                return activeEffect
            }
        }

        return (events, merged)
    }
}
