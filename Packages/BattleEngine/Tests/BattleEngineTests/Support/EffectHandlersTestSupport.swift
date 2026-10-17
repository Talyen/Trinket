import TrinketContent
import TrinketCore
@testable import BattleEngine

enum EffectHandlersTestSupport {
    struct ApplicationObservation {
        let didApply: Bool
        let events: [ActionEvent]
    }

    struct TickObservation {
        let events: [ActionEvent]
        let currentEffect: ActiveEffect?
    }

    static func dispatch(
        _ effect: Effect,
        ability: Ability = Ability(id: "test", name: "Test", tier: .basic),
        source: Combatant? = nil,
        target: Combatant? = nil,
        battle: inout BattleState,
    ) -> ApplicationObservation {
        let source = source ?? battle.hero
        let target = target ?? battle.hero
        let outcome = battle.recordingResult { battle in
            await EffectApplication(effect: effect, ability: ability, source: source, target: target).apply(in: &battle)
        }
        return ApplicationObservation(didApply: outcome.value.didApply, events: outcome.events)
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState,
    ) -> TickObservation {
        battle.roster.mutateRuntime(for: target) {
            $0.activeEffects.removeAll { $0.id == active.id }
            $0.activeEffects.append(active)
        }
        battle.nextEffectID = max(battle.nextEffectID, active.id + 1)
        let outcome = battle.recordingEvents { battle in
            await EffectHandlers.advanceTurn(active, on: target, in: &battle)
        }
        return TickObservation(
            events: outcome,
            currentEffect: battle.roster.activeEffects(for: target).first { $0.id == active.id },
        )
    }
}
