import BattleEngine
import TrinketContent
import TrinketCore

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
        let handler = EffectHandlers.handler(for: effect.kind)
        let outcome = battle.recordingResult { battle in
            await handler.apply(effect, ability: ability, source: source, target: target, in: &battle)
        }
        if battle.tracksLog {
            battle.syncLog()
        }
        return ApplicationObservation(didApply: outcome.value.didApply, events: outcome.events)
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState,
    ) -> TickObservation {
        let handler = EffectHandlers.handler(for: active.effect.kind)
        battle.roster.mutateRuntime(for: target) {
            $0.activeEffects.removeAll { $0.id == active.id }
            $0.activeEffects.append(active)
        }
        battle.nextEffectID = max(battle.nextEffectID, active.id + 1)
        let outcome = battle.recordingEvents { battle in
            await handler.advanceTurn(active, on: target, in: &battle)
        }
        if battle.tracksLog {
            battle.syncLog()
        }
        return TickObservation(
            events: outcome,
            currentEffect: battle.roster.activeEffects(for: target).first { $0.id == active.id },
        )
    }
}
