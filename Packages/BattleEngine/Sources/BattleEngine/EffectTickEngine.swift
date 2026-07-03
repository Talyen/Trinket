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
        }

        return events
    }

    public static func tickEffects(
        _ effects: [ActiveEffect],
        target: Combatant,
        context: inout BattleEngineContext
    ) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var remaining = effects

        guard context.roster.health(for: target) > 0 else {
            return (events, remaining)
        }

        var toRemove: [Int] = []
        for index in remaining.indices {
            guard let handler = EffectHandlers.all[remaining[index].effect.kind] else { continue }
            let outcome = handler.tick(remaining[index], on: target, in: &context)
            events.append(contentsOf: outcome.events)
            if let updated = outcome.updatedStack {
                remaining[index] = updated
            }
            if outcome.removeAfter {
                toRemove.append(index)
            }
        }
        if !toRemove.isEmpty {
            let removeSet = Set(toRemove)
            remaining = remaining.enumerated().compactMap { index, ae in
                removeSet.contains(index) ? nil : ae
            }
        }

        return (events, remaining)
    }
}
