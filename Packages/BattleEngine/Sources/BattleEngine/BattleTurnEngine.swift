import Foundation
import os
import TrinketContent
import TrinketCore

public enum BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine"
    )

    /// Consumes a pending stun/freeze skip for `actor` and records the action.
    ///
    /// The control meter stays at threshold with a linger duration so Stunned /
    /// Frozen status remains through the following player turn without skipping
    /// a second action.
    public static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState
    ) -> [ActionEvent] {
        var keyword: Keyword?

        context.roster.mutateRuntime(for: actor) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: \.isAwaitingActionSkip) else { return }
            var effect = runtime.activeEffects[index]
            keyword = effect.keyword
            let extraSkips = context.additionalControlSkipsByCombatantID[actor.id, default: 0]
            if extraSkips > 0 {
                context.additionalControlSkipsByCombatantID[actor.id] = extraSkips - 1
                effect.remainingTurns = 0
            } else {
                effect.remainingTurns = BattleTiming.controlStatusLingerTurns
            }
            runtime.activeEffects[index] = effect
        }

        guard let keyword else {
            recordAction(for: actor, context: &context)
            return []
        }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .controlActionSkipped,
            actorName: keyword.statusAlias ?? keyword.rawValue,
            abilityName: keyword.statusAlias ?? keyword.rawValue,
            target: actor,
            amount: 0,
            keyword: keyword
        )
        var events = [event]

        if actor.role == .enemy, keyword == .stun {
            events.append(contentsOf: CombatTriggerEngine.afterEnemyStunRecover(in: &context))
        }

        recordAction(for: actor, context: &context)
        return events
    }

    public static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
        chosenBranchIndex: Int? = nil
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        var resolvedAbility = ability.resolvingOutcomeBranch(
            preferredIndex: chosenBranchIndex,
            using: &context.rng
        )
        events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context
        ))

        let damageOutcome = applyDamageComponents(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context
        )
        events.append(contentsOf: damageOutcome.events)

        let appliedEffectLogs = applyTargetedEffects(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            pairedDirectDamage: damageOutcome.pairedDirectDamage,
            context: &context,
            events: &events
        )

        let logKeyword = damageOutcome.logDamageKeyword ?? resolvedAbility.logDamageKeyword
        events.append(
            context.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorID: actor.id,
                actorName: actor.name,
                abilityID: resolvedAbility.id,
                abilityName: resolvedAbility.name,
                abilityTier: resolvedAbility.tier,
                target: abilityTarget,
                amount: damageOutcome.totalDealt,
                keyword: logKeyword,
                appliedEffectSummaries: appliedEffectLogs
            )
        )

        recordAction(for: actor, context: &context)
        return events
    }

    /// Enemy ability selection by action cadence (Basic / Skill@3 / Ultimate@6).
    public static func selectedEnemyAbility(for actor: Combatant, turnNumber: Int) -> Ability? {
        let tier = preferredTier(for: turnNumber)
        return actor.abilityLoadout.ability(for: tier)
            ?? actor.abilityLoadout.basic
            ?? actor.abilities.first
    }

    public static func preferredTier(for turnNumber: Int) -> AbilityTier {
        if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) {
            return .ultimate
        }
        if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) {
            return .skill
        }
        return .basic
    }
}

extension BattleTurnEngine {
    private struct ResolvedDamageComponent {
        let sourceEventID: Int
        let targetID: String
        let healthLost: Int
        let keyword: Keyword
        let isCritical: Bool
    }

    private struct DamageComponentOutcome {
        let events: [ActionEvent]
        let resolvedComponents: [ResolvedDamageComponent]
        let pairedDirectDamage: [PairedDamage]
        let logDamageKeyword: Keyword?

        var totalDealt: Int {
            resolvedComponents.reduce(0) { $0 + $1.healthLost }
        }
    }

    // swiftlint:disable:next function_body_length
    private static func applyDamageComponents(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var resolvedComponents: [ResolvedDamageComponent] = []
        var pairedDirectDamage: [PairedDamage] = []
        var logDamageKeyword: Keyword?
        let keywordOverride = activeDamageKeywordOverride(for: actor, in: context)

        for component in ability.damageComponents {
            let damageTarget = resolveEffectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                context: context
            )

            var amount = component.amount
            if let condition = component.condition,
               BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   enemy: context.enemy,
                   hero: context.hero,
                   companion: context.companion,
                   context: context
               ) {
                amount += component.bonusAmount
            }

            let isSelfHealthCost = damageTarget.id == actor.id
            var damageKeyword = component.keyword
            if amount > 0, !isSelfHealthCost, let override = keywordOverride {
                damageKeyword = override.keyword
                amount += override.bonus
                if component.target == .abilityTarget {
                    logDamageKeyword = override.keyword
                }
            }

            let shouldConsumeNextHolyStrike = amount > 0
                && !isSelfHealthCost
                && damageKeyword == .holy
                && hasActiveEffect(for: actor, in: context) { $0 == .nextHolyStrike }
            let shouldConsumeNextStrikeDouble = amount > 0
                && !isSelfHealthCost
                && hasActiveEffect(for: actor, in: context) { $0 == .nextStrikeDouble }
                && !shouldConsumeNextHolyStrike
            let shouldConsumeNextStrikeCritical = amount > 0
                && !isSelfHealthCost
                && hasActiveEffect(for: actor, in: context) { $0 == .nextStrikeCritical }
            let holyStrikeBurnPotency = amount
            if shouldConsumeNextHolyStrike || shouldConsumeNextStrikeDouble {
                amount *= 2
            }

            let damageOutcome = context.resolveDamage(
                DamageRequest(
                    amount: amount,
                    target: damageTarget,
                    keyword: damageKeyword,
                    sourceActorID: actor.id,
                    options: isSelfHealthCost
                        ? .healthCost
                        : DamageOptions(
                            abilityCriticalChanceBonus: ability.criticalChanceBonus,
                            guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
                            guaranteedCritical: shouldConsumeNextStrikeCritical,
                            qualifiesForAmbush: true,
                            isAttackHit: true,
                            isBasicAttackHit: ability.tier == .basic,
                            abilityHasLeech: ability.hasLeech
                        )
                )
            )
            let dealt = damageOutcome.healthLost
            let damageEvents = damageOutcome.events
            events.append(contentsOf: damageEvents)
            let componentEvent = context.nextEvent(
                kind: .abilityDamage,
                actorID: actor.id,
                actorName: actor.name,
                abilityID: ability.id,
                abilityName: ability.name,
                abilityTier: ability.tier,
                target: damageTarget,
                amount: dealt,
                keyword: damageKeyword,
                isCritical: damageOutcome.flags.contains(.critical)
            )
            events.append(componentEvent)
            resolvedComponents.append(ResolvedDamageComponent(
                sourceEventID: componentEvent.id,
                targetID: damageTarget.id,
                healthLost: dealt,
                keyword: damageKeyword,
                isCritical: componentEvent.isCritical
            ))

            if shouldConsumeNextHolyStrike {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextHolyStrike }
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: holyStrikeBurnPotency,
                    to: damageTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true
                ))
            } else if shouldConsumeNextStrikeDouble {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextStrikeDouble }
            }
            if shouldConsumeNextStrikeCritical {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextStrikeCritical }
            }

            // Pairing feeds on-hit DoT effects; self HP costs are not attack damage.
            if amount > 0, !isSelfHealthCost {
                pairedDirectDamage.append(PairedDamage(keyword: damageKeyword, amount: amount))
            }
        }

        return DamageComponentOutcome(
            events: events,
            resolvedComponents: resolvedComponents,
            pairedDirectDamage: pairedDirectDamage,
            logDamageKeyword: logDamageKeyword
        )
    }

    private static func activeDamageKeywordOverride(
        for actor: Combatant,
        in context: BattleState
    ) -> (keyword: Keyword, bonus: Int)? {
        for active in context.roster.activeEffects(for: actor) where active.remainingTurns > 0 {
            if case let .damageKeywordOverride(keyword, bonus, _) = active.effect {
                return (keyword, bonus)
            }
        }
        return nil
    }

    private static func hasActiveEffect(
        for actor: Combatant,
        in context: BattleState,
        where matches: (Effect) -> Bool
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { matches($0.effect) }
    }

    private static func removeActiveEffect(
        for actor: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool
    ) {
        ActiveEffectMutation.removeMatching(from: actor, in: &context, where: matches)
    }

    private static func applyTargetedEffects(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        pairedDirectDamage: [PairedDamage],
        context: inout BattleState,
        events: inout [ActionEvent]
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        let actionContext = ActionApplyContext(pairedDirectDamage: pairedDirectDamage)

        for targetedEffect in ability.targetedEffects {
            if let condition = targetedEffect.condition,
               !BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   enemy: context.enemy,
                   hero: context.hero,
                   companion: context.companion,
                   context: context
               ) {
                continue
            }

            let effect = targetedEffect.effect
            let effectTarget = resolveEffectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                context: context
            )

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
        context: BattleState
    ) -> Bool {
        guard context.roster.health(for: target) <= 0 else { return false }
        return !effect.canApplyToDefeatedTarget
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleState
    ) {
        context.actionCount += 1
        context.roster.mutateRuntime(for: actor) { runtime in
            runtime.markActed()
        }
    }

    private static func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        context: BattleState
    ) -> Combatant {
        switch target {
        case .abilityTarget:
            return abilityTarget
        case .actor:
            return actor
        case .enemy:
            return context.enemy
        case .hero:
            return context.hero
        case .companion:
            return context.companion
        case .lowestHealthAlly:
            if actor.role == .enemy {
                return context.enemy
            }
            return BattleConditionEvaluator.lowestHealthAlly(
                hero: context.hero,
                companion: context.companion,
                context: context
            )
        case .defeatedAlly:
            if context.roster.health(for: context.companion) <= 0 {
                return context.companion
            }
            if context.roster.health(for: context.hero) <= 0 {
                return context.hero
            }
            // No ally is down: revive has nothing to revive. Return the primary so
            // the handler still rejects deterministically instead of picking the
            // companion arbitrarily.
            return context.hero
        }
    }
}
