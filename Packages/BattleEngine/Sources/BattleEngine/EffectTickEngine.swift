import Foundation
import os
import TrinketContent
import TrinketCore

public enum EffectTickEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "EffectTickEngine"
    )

    public static func tickAll(context: inout BattleEngineContext, matchup: BattleMatchup) -> [ActionEvent] {
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTickOrder {
            let combatant = matchup.combatant(for: participant)
            if participant != .enemy {
                guard context.roster[participant].isAlive else { continue }
            }

            let result = tickEffects(
                context.roster.activeEffects(for: combatant),
                target: combatant,
                context: &context
            )
            context.roster.setActiveEffects(result.updated, for: combatant)
            events.append(contentsOf: result.events)
            events.append(contentsOf: EnemyTraitEngine.tickRegeneration(for: combatant, context: &context))
        }

        return events
    }

    public static func tickEffects(
        _ effects: [ActiveEffect],
        target: Combatant,
        context: inout BattleEngineContext
    ) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var tickOutcomes: [Int: (updatedStack: ActiveEffect?, removeAfter: Bool)] = [:]

        guard context.roster.health(for: target) > 0 else {
            return (events, effects)
        }

        for activeEffect in effects {
            guard context.roster.health(for: target) > 0 else { break }
            guard let handler = EffectHandlers.all[activeEffect.effect.kind] else {
                logger.error(
                    "Missing effect handler for tick of \(String(describing: activeEffect.effect.kind), privacy: .public)"
                )
                continue
            }
            let outcome = handler.tick(activeEffect, on: target, in: &context)
            events.append(contentsOf: outcome.events)
            tickOutcomes[activeEffect.id] = (outcome.updatedStack, outcome.removeAfter)
        }

        var merged = context.roster.activeEffects(for: target)
        if !tickOutcomes.isEmpty {
            merged = merged.compactMap { activeEffect in
                guard let outcome = tickOutcomes[activeEffect.id] else { return activeEffect }
                if outcome.removeAfter { return nil }
                if let updated = outcome.updatedStack {
                    var preserved = activeEffect
                    preserved.remainingTicks = updated.remainingTicks
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
