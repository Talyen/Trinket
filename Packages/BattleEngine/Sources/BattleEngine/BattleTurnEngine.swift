import Foundation
import os
import TrinketContent
import TrinketCore

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
        let turnNumber = (context.roster.runtime(for: actor)?.actionCount ?? 0) + 1
        let currentMana = context.roster.runtime(for: actor)?.currentMana ?? 0

        guard let ability = selectedAbility(for: actor, turnNumber: turnNumber, currentMana: currentMana) else {
            recordAction(for: actor, context: &context)
            return []
        }

        spendManaIfNeeded(for: ability, actor: actor, context: &context)

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
                actorID: actor.id,
                actorName: actor.name,
                abilityID: ability.id,
                abilityName: ability.name,
                abilityTier: ability.tier,
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

    // swiftlint:disable:next function_body_length
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
                enemy: matchup.enemy,
                context: context
            )

            var amount = component.amount
            if let condition = component.condition,
               BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   enemy: matchup.enemy,
                   hero: matchup.hero,
                   pet: matchup.pet,
                   context: context
               ) {
                amount += component.bonusAmount
            }

            let damageOutcome = context.resolveDamage(
                DamageRequest(
                    amount: amount,
                    target: damageTarget,
                    keyword: component.keyword,
                    sourceActorID: actor.id,
                    options: DamageOptions(
                        abilityCriticalChanceBonus: ability.criticalChanceBonus,
                        guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
                        qualifiesForAmbush: true
                    )
                )
            )
            let dealt = damageOutcome.healthLost
            let damageEvents = damageOutcome.events
            events.append(contentsOf: damageEvents)
            if amount > 0 {
                var pairedAmount = amount
                if component.keyword == .bleed {
                    pairedAmount += EnemyTraitEngine.bonusBleedPotency(
                        ability: ability,
                        sourceID: actor.id,
                        in: context
                    )
                }
                pairedDirectDamage.append((component.keyword, pairedAmount))
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
            if let condition = targetedEffect.condition,
               !BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   enemy: matchup.enemy,
                   hero: matchup.hero,
                   pet: matchup.pet,
                   context: context
               ) {
                continue
            }

            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                hero: matchup.hero,
                pet: matchup.pet,
                enemy: matchup.enemy,
                context: context
            )

            // Resource gains (gold/mana) and self-buffs on the actor may still apply after a
            // lethal hit; skip only corpse-targeted combat effects.
            if shouldSkipEffectOnDefeatedTarget(effect, target: effectTarget, actor: actor, context: context) {
                continue
            }

            guard let handler = EffectHandlers.all[effect.kind] else {
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

    private static func shouldSkipEffectOnDefeatedTarget(
        _ effect: Effect,
        target: Combatant,
        actor _: Combatant,
        context: BattleEngineContext
    ) -> Bool {
        guard context.roster.health(for: target) <= 0 else { return false }
        // Gold is party currency and must still grant on a killing blow even when the
        // effect's declared target is the defeated combatant.
        if case .resourceGain(.gold, _) = effect { return false }
        return true
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleEngineContext
    ) {
        context.actionCount += 1
        guard var runtime = context.roster.runtime(for: actor) else { return }
        let activeEffects = context.roster.activeEffects(for: actor)
        runtime.markActed(atTick: context.tickCount, activeEffects: activeEffects)
        context.roster.update(runtime)
    }

    private static func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant,
        context: BattleEngineContext
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
        case .lowestHealthAlly:
            if actor.role == .enemy {
                return enemy
            }
            return BattleConditionEvaluator.lowestHealthAlly(hero: hero, pet: pet, context: context)
        }
    }

    /// Ability that will fire on the combatant's next action, including mana fallback.
    public static func selectedAbility(
        for actor: Combatant,
        turnNumber: Int,
        currentMana: Int
    ) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        let preferred = actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first

        guard let preferred else { return nil }
        guard preferred.manaCost > 0, actor.hasMana else { return preferred }

        if currentMana >= preferred.manaCost {
            return preferred
        }
        return actor.abilityLoadout.basic ?? actor.abilities.first
    }

    public static func spendManaIfNeeded(for ability: Ability, actor: Combatant, context: inout BattleEngineContext) {
        guard ability.manaCost > 0, actor.hasMana else { return }
        _ = context.spendMana(ability.manaCost, for: actor)
    }

    public static func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) { return .ultimate }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) { return .skill }
        return .basic
    }
}
