import Foundation

enum BattleTurnEngine {
    static func readyCombatants(in state: BattleState) -> [Combatant] {
        state.roster.readyCombatants(atTick: state.tickCount).map(\.combatant)
    }

    static func consumePrevention(for actor: Combatant, state: inout BattleState) -> [ActionEvent] {
        var currentEffects = state.roster.activeEffects(for: actor)
        var events: [ActionEvent] = []

        if let index = currentEffects.firstIndex(where: {
            if case .prevention = $0.effect { return true }
            return false
        }) {
            let effect = currentEffects[index]
            let event = state.nextEvent(
                kind: .effect,
                effectKind: .preventionSkipped,
                actorName: effect.keyword.rawValue,
                abilityName: effect.keyword.rawValue,
                target: actor,
                amount: 0,
                keyword: effect.keyword
            )
            events.append(event)

            if effect.remainingTicks <= 1 {
                currentEffects.remove(at: index)
            } else {
                currentEffects[index].remainingTicks -= 1
            }
        }

        state.roster.setActiveEffects(currentEffects, for: actor)
        recordAction(for: actor, state: &state)
        return events
    }

    static func performAction(
        actor: Combatant,
        abilityTarget: Combatant,
        state: inout BattleState
    ) -> [ActionEvent] {
        let turnNumber = state.runtime(for: actor).actionCount + 1

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber) else {
            recordAction(for: actor, state: &state)
            return []
        }

        var events: [ActionEvent] = []

        let (dealt, damageEvents) = state.applyDamage(
            ability.directDamage,
            to: abilityTarget,
            damageKeyword: ability.damageKeyword,
            sourceActorID: actor.id
        )
        events.append(contentsOf: damageEvents)
        if dealt > 0 {
            events.append(contentsOf: state.applyLeechFromDamage(dealt, sourceActorID: actor.id))
        }

        var appliedEffectLogs: [String] = []
        let effectsToApply: [TargetedEffect] = ability.targetedEffects.isEmpty
            ? (ability.statusApplication.map {
                [TargetedEffect(Effect.effect(from: $0), target: .abilityTarget)]
            } ?? [])
            : ability.targetedEffects

        var context = state.makeMutationContext()
        if ability.directDamage > 0 {
            context.pairedDirectDamage = [(ability.damageKeyword, ability.directDamage)]
        }
        for targetedEffect in effectsToApply {
            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                state: state
            )

            guard let handler = EffectHandlers.all[effect.kind] else { continue }
            let outcome = handler.apply(
                effect,
                ability: ability,
                source: actor,
                target: effectTarget,
                in: &context
            )
            events.append(contentsOf: outcome.events)
            if outcome.didApply {
                appliedEffectLogs.append(effect.summary)
            }
        }
        state.applyMutationContext(context)

        events.append(
            state.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorName: actor.name,
                abilityName: ability.name,
                target: abilityTarget,
                amount: dealt,
                keyword: ability.damageKeyword,
                appliedEffectSummaries: appliedEffectLogs
            )
        )

        recordAction(for: actor, state: &state)
        return events
    }

    private static func recordAction(for actor: Combatant, state: inout BattleState) {
        state.actionCount += 1
        var runtime = state.runtime(for: actor)
        runtime.markActed(atTick: state.tickCount)
        state.updateRuntime(runtime)
    }

    private static func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        state: BattleState
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return state.enemy
        case .hero:
            return state.hero
        case .pet:
            return state.pet
        }
    }

    private static func selectedAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    private static func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) { return .ultimate }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) { return .skill }
        return .basic
    }
}
