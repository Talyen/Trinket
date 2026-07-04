import Foundation
import os
import TrinketCore
import TrinketContent

public enum BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine"
    )
    public static func readyCombatants(in context: BattleEngineContext) -> [Combatant] {
        context.roster.readyCombatants(atTick: context.tickCount).map(\.combatant)
    }

    /// Acts on `actor` for one turn. If the actor has stun/freeze buildup at
    /// threshold, the skip is consumed and the actor's schedule still advances.
    /// Otherwise the actor's selected ability is performed against
    /// `context.roster.enemyAttackTarget` (or `matchup.enemy` for non-enemy actors).
    public static func act(
        actor: Combatant,
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let abilityTarget = actor.role == .enemy ? context.roster.enemyAttackTarget : matchup.enemy
        if context.roster.hasPendingActionSkip(for: actor) {
            return consumeActionSkip(for: actor, context: &context)
        }
        return performAction(
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
            context: &context
        )
    }

    public static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        var currentEffects = context.roster.activeEffects(for: actor)
        guard let index = currentEffects.firstIndex(where: { $0.effect.isActionSkipPending }) else {
            recordAction(for: actor, context: &context)
            return []
        }

        let effect = currentEffects[index]
        let keyword = effect.keyword
        currentEffects.remove(at: index)
        context.roster.setActiveEffects(currentEffects, for: actor)

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .controlActionSkipped,
            actorName: keyword.statusAlias ?? keyword.rawValue,
            abilityName: keyword.statusAlias ?? keyword.rawValue,
            target: actor,
            amount: 0,
            keyword: keyword
        )
        recordAction(for: actor, context: &context)
        return [event]
    }

    public static func performAction(
        actor: Combatant,
        abilityTarget: Combatant,
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let turnNumber = context.runtime(for: actor).actionCount + 1

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber) else {
            recordAction(for: actor, context: &context)
            return []
        }

        var events: [ActionEvent] = []
        let damageOutcome = applyDamageComponents(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
            context: &context
        )
        events.append(contentsOf: damageOutcome.events)

        let appliedEffectLogs = applyTargetedEffects(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
            pairedDirectDamage: damageOutcome.pairedDirectDamage,
            context: &context,
            events: &events
        )

        events.append(
            context.nextEvent(
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

        recordAction(for: actor, context: &context)
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
        matchup: BattleMatchup,
        context: inout BattleEngineContext
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var totalDealtToAbilityTarget = 0
        var pairedDirectDamage: [(Keyword, Int)] = []

        for component in ability.damageComponents {
            let damageTarget = resolveEffectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                hero: matchup.hero,
                pet: matchup.pet,
                enemy: matchup.enemy
            )
            let (dealt, damageEvents) = context.applyDamage(
                component.amount,
                to: damageTarget,
                damageKeyword: component.keyword,
                sourceActorID: actor.id
            )
            events.append(contentsOf: damageEvents)
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
        matchup: BattleMatchup,
        pairedDirectDamage: [(Keyword, Int)],
        context: inout BattleEngineContext,
        events: inout [ActionEvent]
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        let actionContext = ActionApplyContext(pairedDirectDamage: pairedDirectDamage)

        for targetedEffect in ability.targetedEffects {
            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                hero: matchup.hero,
                pet: matchup.pet,
                enemy: matchup.enemy
            )

            guard let handler = EffectHandlers.all[effect.kind] else {
                assertionFailure("Missing effect handler for \(effect.kind)")
                logger.error("Missing effect handler for \(String(describing: effect.kind), privacy: .public)")
                continue
            }
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
        return appliedEffectLogs
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleEngineContext
    ) {
        context.actionCount += 1
        var runtime = context.runtime(for: actor)
        runtime.markActed(atTick: context.tickCount)
        context.updateRuntime(runtime)
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
