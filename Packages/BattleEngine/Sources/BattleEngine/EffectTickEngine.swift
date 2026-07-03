import Foundation
import TrinketCore
import TrinketContent

public enum EffectTickEngine {
    public static func tickAll(context: inout BattleEngineContext, matchup: BattleMatchup) -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickEffects(
            context.activeEffects(for: matchup.enemy),
            target: matchup.enemy,
            context: &context
        )
        context.setActiveEffects(enemyResult.updated, for: matchup.enemy)
        events.append(contentsOf: enemyResult.events)

        if context.roster.hero.isAlive {
            let heroResult = tickEffects(
                context.activeEffects(for: matchup.hero),
                target: matchup.hero,
                context: &context
            )
            context.setActiveEffects(heroResult.updated, for: matchup.hero)
            events.append(contentsOf: heroResult.events)
        }

        if context.roster.pet.isAlive {
            let petResult = tickEffects(
                context.activeEffects(for: matchup.pet),
                target: matchup.pet,
                context: &context
            )
            context.setActiveEffects(petResult.updated, for: matchup.pet)
            events.append(contentsOf: petResult.events)
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
