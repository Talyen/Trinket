import Foundation

enum EffectTickEngine {
    static func tickAll(state: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickEffects(state.activeEffects(for: .enemy), target: state.enemy, state: &state)
        state.roster.setActiveEffects(enemyResult.updated, for: state.enemy)
        events.append(contentsOf: enemyResult.events)

        if state.isHeroAlive {
            let heroResult = tickEffects(state.activeEffects(for: .hero), target: state.hero, state: &state)
            state.roster.setActiveEffects(heroResult.updated, for: state.hero)
            events.append(contentsOf: heroResult.events)
        }

        if state.isPetAlive {
            let petResult = tickEffects(state.activeEffects(for: .pet), target: state.pet, state: &state)
            state.roster.setActiveEffects(petResult.updated, for: state.pet)
            events.append(contentsOf: petResult.events)
        }

        return events
    }

    static func tickEffects(
        _ effects: [ActiveEffect],
        target: Combatant,
        state: inout BattleState
    ) -> (events: [ActionEvent], updated: [ActiveEffect]) {
        var events: [ActionEvent] = []
        var remaining = effects

        guard state.roster.health(for: target) > 0 else {
            return (events, remaining)
        }

        var toRemove: [Int] = []
        state.withEngineContext { context in
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
