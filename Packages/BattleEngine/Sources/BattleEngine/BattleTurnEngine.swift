import Foundation
import os
import TrinketContent
import TrinketCore

public enum BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine"
    )

    /// Resolves an explicit ability for `actor` against the standard ability target.
    public static func performAbility(
        _ ability: Ability,
        actor: Combatant,
        matchup: BattleMatchup,
        context: inout BattleEngineContext,
        spendMana: Bool = false
    ) -> [ActionEvent] {
        let abilityTarget = actor.role == .enemy ? context.roster.enemyAttackTarget : matchup.enemy
        var events: [ActionEvent] = []
        events.append(contentsOf: performAction(
            ability: ability,
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
            context: &context,
            spendMana: spendMana
        ))
        return events
    }

    /// Consumes a pending stun/freeze skip for `actor` and records the action.
    public static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        var currentEffects = context.roster.activeEffects(for: actor)
        guard let index = currentEffects.firstIndex(where: { $0.effect.isActionSkipPending }) else {
            return recordAction(for: actor, context: &context)
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
        var events = [event]
        events.append(contentsOf: recordAction(for: actor, context: &context))
        return events
    }

    public static func performAction(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        matchup: BattleMatchup,
        context: inout BattleEngineContext,
        spendMana: Bool
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        var resolvedAbility = ability.resolvingOutcomeBranch(using: &context.rng)
        events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context
        ))
        if spendMana {
            events.append(contentsOf: spendManaIfNeeded(for: resolvedAbility, actor: actor, context: &context))
        }

        let damageOutcome = applyDamageComponents(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
            context: &context
        )
        events.append(contentsOf: damageOutcome.events)

        let appliedEffectLogs = applyTargetedEffects(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            matchup: matchup,
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
                amount: damageOutcome.totalDealtToAbilityTarget,
                keyword: logKeyword,
                appliedEffectSummaries: appliedEffectLogs
            )
        )

        events.append(contentsOf: recordAction(for: actor, context: &context))
        return events
    }

    /// Enemy ability selection by action cadence (Basic / Skill@3 / Ultimate@6). Mana is ignored.
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

    @discardableResult
    public static func spendManaIfNeeded(for ability: Ability, actor: Combatant, context: inout BattleEngineContext) -> [ActionEvent] {
        guard ability.manaCost > 0, actor.hasMana else { return [] }
        let cost = context.modifiers(for: actor.id).effectiveManaCost(for: ability)
        guard cost > 0 else { return [] }
        let spent = context.spendMana(cost, for: actor)
        guard spent > 0 else { return [] }
        return CombatReactionEngine.afterSpendMana(by: actor, in: &context)
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
        let pairedDirectDamage: [(Keyword, Int)]
        let logDamageKeyword: Keyword?

        var totalDealtToAbilityTarget: Int {
            resolvedComponents.reduce(0) { $0 + $1.healthLost }
        }
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
        var resolvedComponents: [ResolvedDamageComponent] = []
        var pairedDirectDamage: [(Keyword, Int)] = []
        var logDamageKeyword: Keyword?
        let keywordOverride = activeDamageKeywordOverride(for: actor, in: context)

        for component in ability.damageComponents {
            let damageTarget = resolveEffectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                hero: matchup.hero,
                companion: matchup.companion,
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
                   companion: matchup.companion,
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
                && hasNextHolyStrike(for: actor, in: context)
            let shouldConsumeNextStrikeDouble = amount > 0
                && !isSelfHealthCost
                && hasNextStrikeDouble(for: actor, in: context)
                && !shouldConsumeNextHolyStrike
            let shouldConsumeNextStrikeCritical = amount > 0
                && !isSelfHealthCost
                && hasNextStrikeCritical(for: actor, in: context)
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
                            abilityHasLeech: ability.hasLeech
                        )
                )
            )
            let dealt = damageOutcome.healthLost
            let damageEvents = damageOutcome.events
            events.append(contentsOf: damageEvents)
            if component.target == .abilityTarget {
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
            }

            if shouldConsumeNextHolyStrike {
                removeNextHolyStrike(for: actor, in: &context)
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: amount,
                    to: damageTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true
                ))
            } else if shouldConsumeNextStrikeDouble {
                removeNextStrikeDouble(for: actor, in: &context)
            }
            if shouldConsumeNextStrikeCritical {
                removeNextStrikeCritical(for: actor, in: &context)
            }

            // Pairing feeds on-hit DoT effects; self HP costs are not attack damage.
            if amount > 0, !isSelfHealthCost {
                var pairedAmount = amount
                if damageKeyword == .bleed {
                    pairedAmount += EnemyTraitEngine.bonusBleedPotency(
                        ability: ability,
                        sourceID: actor.id,
                        in: context
                    )
                }
                pairedDirectDamage.append((damageKeyword, pairedAmount))
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
        in context: BattleEngineContext
    ) -> (keyword: Keyword, bonus: Int)? {
        for active in context.roster.activeEffects(for: actor) where active.remainingTurns > 0 {
            if case let .damageKeywordOverride(keyword, bonus, _) = active.effect {
                return (keyword, bonus)
            }
            if case .holyDamageBonusFromBlock = active.effect {
                let block = DefensePoolEngine.points(
                    in: context.roster.activeEffects(for: actor),
                    pool: .block
                )
                return (.holy, block)
            }
        }
        return nil
    }

    private static func hasNextHolyStrike(
        for actor: Combatant,
        in context: BattleEngineContext
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { active in
            if case .nextHolyStrike = active.effect {
                return true
            }
            return false
        }
    }

    private static func removeNextHolyStrike(
        for actor: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: actor)
        effects.removeAll {
            if case .nextHolyStrike = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: actor)
    }

    private static func hasNextStrikeDouble(
        for actor: Combatant,
        in context: BattleEngineContext
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { active in
            if case .nextStrikeDouble = active.effect {
                return true
            }
            return false
        }
    }

    private static func removeNextStrikeDouble(
        for actor: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: actor)
        effects.removeAll {
            if case .nextStrikeDouble = $0.effect {
                return true
            }
            return false
        }
        context.roster.setActiveEffects(effects, for: actor)
    }

    private static func hasNextStrikeCritical(
        for actor: Combatant,
        in context: BattleEngineContext
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { active in
            if case .nextStrikeCritical = active.effect {
                return true
            }
            return false
        }
    }

    private static func removeNextStrikeCritical(
        for actor: Combatant,
        in context: inout BattleEngineContext
    ) {
        var effects = context.roster.activeEffects(for: actor)
        effects.removeAll {
            if case .nextStrikeCritical = $0.effect {
                return true
            }
            return false
        }
        context.roster.setActiveEffects(effects, for: actor)
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
                   companion: matchup.companion,
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
                companion: matchup.companion,
                enemy: matchup.enemy,
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
        context: BattleEngineContext
    ) -> Bool {
        guard context.roster.health(for: target) <= 0 else { return false }
        if case .resourceGain(.gold, _) = effect {
            return false
        }
        if case .drawCards = effect {
            return false
        }
        if case .revive = effect {
            return false
        }
        return true
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleEngineContext
    ) -> [ActionEvent] {
        context.actionCount += 1
        guard var runtime = context.roster.runtime(for: actor) else { return [] }
        runtime.markActed()
        context.roster.update(runtime)
        return []
    }

    private static func resolveEffectTarget(
        _ target: EffectTarget,
        actor: Combatant,
        abilityTarget: Combatant,
        hero: Combatant,
        companion: Combatant,
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
        case .companion:
            return companion
        case .lowestHealthAlly:
            if actor.role == .enemy {
                return enemy
            }
            return BattleConditionEvaluator.lowestHealthAlly(hero: hero, companion: companion, context: context)
        case .defeatedAlly:
            if context.roster.health(for: companion) <= 0 {
                return companion
            }
            if context.roster.health(for: hero) <= 0 {
                return hero
            }
            return companion
        }
    }
}
