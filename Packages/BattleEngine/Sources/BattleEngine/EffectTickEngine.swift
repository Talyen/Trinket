import Foundation
import TrinketCore
import TrinketContent

public enum EffectTickEngine {
    public static func tickAll(context: inout BattleEngineContext, matchup: BattleMatchup) -> [ActionEvent] {
        var events: [ActionEvent] = []

        for participant in BattleParticipant.effectTickOrder {
            let combatant = matchup.combatant(for: participant)
            if participant != .enemy {
                guard context.roster[participant].isAlive else { continue }
            }

            let result = tickEffects(
                context.activeEffects(for: combatant),
                target: combatant,
                context: &context
            )
            context.setActiveEffects(result.updated, for: combatant)
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
            guard let handler = EffectHandlers.all[activeEffect.effect.kind] else { continue }
            let outcome = handler.tick(activeEffect, on: target, in: &context)
            events.append(contentsOf: outcome.events)
            tickOutcomes[activeEffect.id] = (outcome.updatedStack, outcome.removeAfter)
        }

        var merged = context.activeEffects(for: target)
        merged = merged.compactMap { activeEffect in
            guard let outcome = tickOutcomes[activeEffect.id] else { return activeEffect }
            if outcome.removeAfter { return nil }
            if let updated = outcome.updatedStack { return updated }
            return activeEffect
        }

        return (events, merged)
    }
}
