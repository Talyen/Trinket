import Foundation
import TrinketCore
import TrinketContent

public enum BattleTurnEngine {
    public static func readyCombatants(in state: BattleState) -> [Combatant] {
        state.roster.readyCombatants(atTick: state.tickCount).map(\.combatant)
    }

    /// Acts on `actor` for one turn. If the actor has an active `.prevention`
    /// effect with `remainingTicks > 0`, the prevention is consumed and the
    /// actor's schedule still advances. Otherwise the actor's selected
    /// ability is performed against `state.enemyAttackTarget` (or `state.enemy`
    /// for non-enemy actors).
    public static func act(actor: Combatant, state: inout BattleState) -> [ActionEvent] {
        let abilityTarget = actor.role == .enemy ? state.enemyAttackTarget : state.enemy
        if state.roster.hasActivePrevention(for: actor) {
            return consumePrevention(for: actor, state: &state)
        }
        return performAction(actor: actor, abilityTarget: abilityTarget, state: &state)
    }

    public static func consumePrevention(for actor: Combatant, state: inout BattleState) -> [ActionEvent] {
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

    public static func performAction(
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
        let damageOutcome = applyDamageComponents(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            state: &state
        )
        events.append(contentsOf: damageOutcome.events)

        let appliedEffectLogs = applyTargetedEffects(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            pairedDirectDamage: damageOutcome.pairedDirectDamage,
            state: &state,
            events: &events
        )

        events.append(
            state.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorName: actor.name,
                abilityName: ability.name,
                target: abilityTarget,
                amount: damageOutcome.totalDealtToAbilityTarget,
                keyword: ability.logDamageKeyword,
                appliedEffectSummaries: appliedEffectLogs
            )
        )

        recordAction(for: actor, state: &state)
        return events
    }

    private struct DamageComponentOutcome {
        let events: [ActionEvent]
        let pairedDirectDamage: [(Keyword, Int)]
        let totalDealtToAbilityTarget: Int
    }

    private static func applyDamageComponents(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        state: inout BattleState
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var totalDealtToAbilityTarget = 0
        var pairedDirectDamage: [(Keyword, Int)] = []

        for component in ability.damageComponents {
            let damageTarget = resolveEffectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                hero: state.hero,
                pet: state.pet,
                enemy: state.enemy
            )
            let (dealt, damageEvents) = state.applyDamage(
                component.amount,
                to: damageTarget,
                damageKeyword: component.keyword,
                sourceActorID: actor.id
            )
            events.append(contentsOf: damageEvents)
            if dealt > 0, damageTarget.id != actor.id {
                events.append(contentsOf: state.applyLeechFromDamage(dealt, sourceActorID: actor.id))
            }
            if component.amount > 0 {
                pairedDirectDamage.append((component.keyword, component.amount))
            }
            if component.target == .abilityTarget {
                totalDealtToAbilityTarget += dealt
            }
        }

        return DamageComponentOutcome(
            events: events,
            pairedDirectDamage: pairedDirectDamage,
            totalDealtToAbilityTarget: totalDealtToAbilityTarget
        )
    }

    private static func applyTargetedEffects(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        pairedDirectDamage: [(Keyword, Int)],
        state: inout BattleState,
        events: inout [ActionEvent]
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        let actionContext = ActionApplyContext(pairedDirectDamage: pairedDirectDamage)
        let heroCombatant = state.hero
        let petCombatant = state.pet
        let enemyCombatant = state.enemy
        state.withEngineContext { context in
            for targetedEffect in ability.targetedEffects {
                let effect = targetedEffect.effect
                let effectTarget = resolveEffectTarget(
                    targetedEffect.target,
                    actor: actor,
                    abilityTarget: abilityTarget,
                    hero: heroCombatant,
                    pet: petCombatant,
                    enemy: enemyCombatant
                )

                guard let handler = EffectHandlers.all[effect.kind] else { continue }
                let outcome = handler.apply(
                    effect,
                    ability: ability,
                    source: actor,
                    target: effectTarget,
                    action: actionContext,
                    in: &context
                )
                events.append(contentsOf: outcome.events)
                if outcome.didApply {
                    appliedEffectLogs.append(effect.summary)
                }
            }
        }
        return appliedEffectLogs
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
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return enemy
        case .hero:
            return hero
        case .pet:
            return pet
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
