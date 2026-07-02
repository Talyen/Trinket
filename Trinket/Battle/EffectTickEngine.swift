import Foundation

enum EffectTickEngine {
    static func tickAll(state: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        let enemyResult = tickEffects(state.activeEnemyEffects, target: state.enemy, state: &state)
        state.roster.setActiveEffects(enemyResult.updated, for: state.enemy)
        events.append(contentsOf: enemyResult.events)

        if state.isHeroAlive {
            let heroResult = tickEffects(state.activeHeroEffects, target: state.hero, state: &state)
            state.roster.setActiveEffects(heroResult.updated, for: state.hero)
            events.append(contentsOf: heroResult.events)
        }

        if state.isPetAlive {
            let petResult = tickEffects(state.activePetEffects, target: state.pet, state: &state)
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
        var context = state.makeMutationContext()
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
        state.applyMutationContext(context)
        if !toRemove.isEmpty {
            let removeSet = Set(toRemove)
            remaining = remaining.enumerated().compactMap { index, ae in
                removeSet.contains(index) ? nil : ae
            }
        }

        for ae in remaining {
            switch ae.effect {
            case let .cleanse(cleanseKeyword, _):
                if let removeKeyword = cleanseKeyword {
                    remaining.removeAll { $0.keyword == removeKeyword }
                } else {
                    remaining.removeAll { $0.effect.isTickable }
                }
                remaining.append(ae)

            default:
                break
            }
        }

        remaining = remaining.compactMap { ae in
            switch ae.effect {
            case .burn(0), .poison(0):
                return nil
            case .bleed:
                return ae.remainingTicks > 0 ? ae : nil
            case .burn, .poison:
                return ae
            case .prevention, .preventionBuildup:
                return ae
            default:
                var updated = ae
                updated.remainingTicks -= 1
                return updated.remainingTicks > 0 ? updated : nil
            }
        }

        return (events, remaining)
    }
}
