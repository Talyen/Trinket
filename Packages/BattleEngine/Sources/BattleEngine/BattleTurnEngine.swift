import Foundation
import os
import TrinketContent
import TrinketCore

public enum BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine",
    )

    public static func consumeActionSkip(
        for actor: Combatant,
        context: inout BattleState,
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
            keyword: keyword,
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
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        guard BattleAbilityRules.canPayHealthCost(ability, actor: actor, in: context) else { return [] }
        var resolvedAbility = BattleAbilityRules.resolveOutcome(ability, actor: actor, in: &context)
        events.append(contentsOf: spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &resolvedAbility,
            actor: actor,
            context: &context,
        ))
        if resolvedAbility.dealsCombatDamage {
            events.append(contentsOf: consumeHemorrhageIfActive(for: actor, in: &context))
        }

        let damageOutcome = applyDamageComponents(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context,
        )
        events.append(contentsOf: damageOutcome.events)

        let appliedEffectLogs = applyTargetedEffects(
            ability: resolvedAbility,
            actor: actor,
            abilityTarget: abilityTarget,
            context: &context,
            events: &events,
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
                appliedEffectSummaries: appliedEffectLogs,
            ),
        )

        recordAction(for: actor, context: &context)
        return events
    }

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
        let logDamageKeyword: Keyword?

        var totalDealt: Int {
            resolvedComponents.reduce(0) { $0 + $1.healthLost }
        }
    }

    // swiftlint:disable:next function_body_length - end-turn mutations must remain in deterministic order
    private static func applyDamageComponents(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var resolvedComponents: [ResolvedDamageComponent] = []
        var logDamageKeyword: Keyword?
        let keywordOverride = activeDamageKeywordOverride(for: actor, in: context)

        for component in ability.damageComponents {
            let damageTarget = BattleTargetResolver.effectTarget(
                component.target,
                actor: actor,
                abilityTarget: abilityTarget,
                in: context,
            )

            var amount = component.amount
            if let condition = component.condition {
                if BattleConditionEvaluator.isMet(
                    condition,
                    actor: actor,
                    in: context,
                ) {
                    amount += component.bonusAmount
                } else if component.bonusAmount == 0 {
                    continue
                }
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
            let nextBurnBonus = amount > 0 && !isSelfHealthCost && damageKeyword == .burn
                ? activeNextBurnBonus(for: actor, in: context)
                : 0
            if nextBurnBonus > 0 {
                amount += nextBurnBonus
            }
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
                            abilityHasLeech: ability.hasLeech,
                        ),
                ),
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
                isCritical: damageOutcome.flags.contains(.critical),
            )
            events.append(componentEvent)
            resolvedComponents.append(ResolvedDamageComponent(
                sourceEventID: componentEvent.id,
                targetID: damageTarget.id,
                healthLost: dealt,
                keyword: damageKeyword,
                isCritical: componentEvent.isCritical,
            ))

            if shouldConsumeNextHolyStrike {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextHolyStrike }
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: holyStrikeBurnPotency,
                    to: damageTarget,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true,
                ))
            } else if shouldConsumeNextStrikeDouble {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextStrikeDouble }
            }
            if shouldConsumeNextStrikeCritical {
                removeActiveEffect(for: actor, in: &context) { $0 == .nextStrikeCritical }
            }
            if nextBurnBonus > 0 {
                removeActiveEffect(for: actor, in: &context) {
                    if case .nextBurnBonus = $0 {
                        return true
                    }
                    return false
                }
            }
            if amount > 0, !isSelfHealthCost {
                events.append(contentsOf: applyDoTStackFromDamage(
                    keyword: damageKeyword,
                    potency: amount,
                    to: damageTarget,
                    sourceActorID: actor.id,
                    context: &context,
                ))
            }
        }

        return DamageComponentOutcome(
            events: events,
            resolvedComponents: resolvedComponents,
            logDamageKeyword: logDamageKeyword,
        )
    }

    private static func applyDoTStackFromDamage(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        context: inout BattleState,
    ) -> [ActionEvent] {
        switch keyword {
        case .burn, .poison:
            context.applyDecayingDoT(
                keyword: keyword,
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
            )
        case .bleed:
            DoTApplicator.applyBleed(
                potency: potency,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                in: &context,
            )
        default:
            []
        }
    }

    private static func activeDamageKeywordOverride(
        for actor: Combatant,
        in context: BattleState,
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
        where matches: (Effect) -> Bool,
    ) -> Bool {
        context.roster.activeEffects(for: actor).contains { matches($0.effect) }
    }

    private static func activeNextBurnBonus(
        for actor: Combatant,
        in context: BattleState,
    ) -> Int {
        context.roster.activeEffects(for: actor).reduce(0) { sum, active in
            if case let .nextBurnBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
    }

    private static func removeActiveEffect(
        for actor: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool,
    ) {
        ActiveEffectMutation.removeMatching(from: actor, in: &context, where: matches)
    }

    private static func consumeHemorrhageIfActive(
        for actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var hemorrhageDamage: Int?
        var sourceActorID: String?
        for active in context.roster.activeEffects(for: actor) {
            if case let .hemorrhage(damage) = active.effect {
                hemorrhageDamage = damage
                sourceActorID = active.sourceActorID
                break
            }
        }
        guard let hemorrhageDamage else { return [] }
        removeActiveEffect(for: actor, in: &context) {
            if case .hemorrhage = $0 {
                return true
            }
            return false
        }
        let casterID = sourceActorID ?? actor.id
        let hemorrhageOutcome = context.resolveDamage(
            DamageRequest(
                amount: hemorrhageDamage,
                target: actor,
                keyword: .bleed,
                sourceActorID: casterID,
                options: .flatReaction,
            ),
        )
        var hemorrhageEvents = hemorrhageOutcome.events
        if let lastIndex = hemorrhageEvents.indices.last {
            let event = hemorrhageEvents[lastIndex]
            hemorrhageEvents[lastIndex] = event.with(
                effectKind: .hemorrhageTriggered,
                actorID: actor.id,
                actorName: actor.name,
                abilityName: "Hemorrhage",
            )
        } else if hemorrhageOutcome.healthLost > 0 {
            hemorrhageEvents.append(context.nextEvent(
                kind: .effect,
                effectKind: .hemorrhageTriggered,
                actorID: actor.id,
                actorName: actor.name,
                abilityName: "Hemorrhage",
                target: actor,
                amount: hemorrhageOutcome.healthLost,
                keyword: .bleed,
            ))
        }
        hemorrhageEvents.append(contentsOf: DoTApplicator.applyBleed(
            potency: hemorrhageDamage,
            to: actor,
            sourceActorID: casterID,
            dealImmediateDamage: false,
            in: &context,
        ))
        return hemorrhageEvents
    }

    private static func applyTargetedEffects(
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
        events: inout [ActionEvent],
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        for targetedEffect in ability.targetedEffects {
            if let condition = targetedEffect.condition,
               !BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   in: context,
               ) {
                continue
            }

            let effect = targetedEffect.effect
            let effectTarget = BattleTargetResolver.effectTarget(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                in: context,
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
                in: &context,
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
        context: BattleState,
    ) -> Bool {
        guard context.roster.health(for: target) <= 0 else { return false }
        return !effect.canApplyToDefeatedTarget
    }

    private static func recordAction(
        for actor: Combatant,
        context: inout BattleState,
    ) {
        context.actionCount += 1
        context.roster.mutateRuntime(for: actor) { runtime in
            runtime.markActed()
        }
    }
}
