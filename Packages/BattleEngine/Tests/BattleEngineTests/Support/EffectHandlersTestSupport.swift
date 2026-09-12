import BattleEngine
import TrinketContent
import TrinketCore

enum EffectHandlersTestSupport {
    struct TickObservation {
        let events: [ActionEvent]
        let currentEffect: ActiveEffect?
    }

    static func dispatch(
        _ effect: Effect,
        ability: Ability = Ability(id: "test", name: "Test", tier: .basic),
        source: Combatant,
        target: Combatant,
        battle: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let handler = EffectHandlers.handler(for: effect.kind) else {
            preconditionFailure("Missing handler for \(effect.kind)")
        }
        return battle.withEngineContext { context in
            handler.apply(
                effect,
                ability: ability,
                source: source,
                target: target,
                in: &context,
            )
        }
    }

    static func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState,
    ) -> TickObservation {
        guard let handler = EffectHandlers.handler(for: active.effect.kind) else {
            preconditionFailure("Missing handler for \(active.effect.kind)")
        }
        return battle.withEngineContext { context in
            context.roster.mutateRuntime(for: target) {
                $0.activeEffects.removeAll { $0.id == active.id }
                $0.activeEffects.append(active)
            }
            context.nextEffectID = max(context.nextEffectID, active.id + 1)
            let outcome = handler.advanceTurn(active, on: target, in: &context)
            return TickObservation(
                events: outcome,
                currentEffect: context.roster.activeEffects(for: target).first { $0.id == active.id },
            )
        }
    }
}
