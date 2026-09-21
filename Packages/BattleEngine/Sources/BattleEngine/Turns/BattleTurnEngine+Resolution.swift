import Foundation
import os
import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine",
    )

    struct ResolvedDamageComponent {
        let sourceEventID: Int
        let targetID: String
        let healthLost: Int
        let keyword: Keyword
        let isCritical: Bool
    }

    struct DamageComponentOutcome {
        let events: [ActionEvent]
        let resolvedComponents: [ResolvedDamageComponent]
        let logDamageKeyword: Keyword?

        var totalDealt: Int {
            resolvedComponents.reduce(0) { $0 + $1.healthLost }
        }
    }

    // swiftlint:disable:next function_body_length - attack components resolve in deterministic order
    static func applyDamageComponents(
        _ components: [DamageComponent],
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        guaranteedCritical: Bool,
        context: inout BattleState,
    ) -> DamageComponentOutcome {
        var events: [ActionEvent] = []
        var resolvedComponents: [ResolvedDamageComponent] = []
        var logDamageKeyword: Keyword?
        let keywordOverride = activeDamageKeywordOverride(for: actor, in: context)

        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        for component in components {
            guard action.canContinue(in: context) else { break }
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
                    abilityTarget: abilityTarget,
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

            let nextBurnBonus = amount > 0 && !isSelfHealthCost && damageKeyword == .burn
                ? activeNextBurnBonus(for: actor, in: context)
                : 0
            let nextStrike = nextStrikeConsumption(
                amount: amount,
                damageKeyword: damageKeyword,
                isSelfHealthCost: isSelfHealthCost,
                actor: actor,
                nextBurnBonus: nextBurnBonus,
                in: context,
            )
            if nextBurnBonus > 0 {
                amount += nextBurnBonus
            }
            let holyStrikeBurnPotency = amount
            if nextStrike.contains(.holyStrike) || nextStrike.contains(.double) {
                amount *= 2
            }

            ActiveEffectMutation.removeMatching(from: actor, in: &context) { nextStrike.consumedKinds.contains($0.kind) }
            let options: DamageOperation = isSelfHealthCost
                ? .healthCost
                : .attack(
                    tier: ability.tier,
                    origin: context.resolution.attackOrigin,
                    abilityCriticalChanceBonus: ability.criticalChanceBonus,
                    guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
                    guaranteedCritical: guaranteedCritical || nextStrike.contains(.critical),
                    abilityHasLeech: ability.hasLeech || nextStrike.contains(.leech),
                )
            var request = DamageRequest(
                amount: amount,
                target: damageTarget,
                keyword: damageKeyword,
                sourceActorID: actor.id,
                options: options,
            )
            if !isSelfHealthCost {
                request.provenance = context.resolution.damageProvenance(for: actor.id)
            }
            request = UniqueCombatEngine.prepareDamage(request, in: &context)
            let damageOutcome = context.resolveDamage(request)
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
                origin: .direct,
            )
            events.append(componentEvent)
            resolvedComponents.append(ResolvedDamageComponent(
                sourceEventID: componentEvent.id,
                targetID: damageTarget.id,
                healthLost: dealt,
                keyword: damageKeyword,
                isCritical: componentEvent.isCritical,
            ))

            if case .landed = damageOutcome.damageImpact {
                if nextStrike.contains(.holyStrike) {
                    events.append(contentsOf: context.applyDecayingDoT(
                        keyword: .burn, potency: holyStrikeBurnPotency, to: damageTarget,
                        sourceActorID: actor.id, application: .ability,
                    ))
                }
                events.append(contentsOf: applyDoTStackFromDamage(
                    keyword: damageKeyword,
                    potency: damageKeyword == .burn || damageKeyword == .poison ? dealt : amount,
                    to: damageTarget,
                    sourceActorID: actor.id, context: &context,
                ))
            }
        }

        return DamageComponentOutcome(
            events: events,
            resolvedComponents: resolvedComponents,
            logDamageKeyword: logDamageKeyword,
        )
    }

    static func applyDoTStackFromDamage(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        context: inout BattleState,
    ) -> [ActionEvent] {
        DoTApplicator.applyDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            application: .afterHit,
            in: &context,
        ) ?? []
    }

    static func activeDamageKeywordOverride(
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

    private static func nextStrikeConsumption(
        amount: Int,
        damageKeyword: Keyword?,
        isSelfHealthCost: Bool,
        actor: Combatant,
        nextBurnBonus: Int,
        in context: BattleState,
    ) -> NextStrikeConsumption {
        guard amount > 0, !isSelfHealthCost else { return [] }
        var consumption: NextStrikeConsumption = []
        let holyStrike = damageKeyword == .holy
            && hasActiveEffect(for: actor, in: context) { $0 == .nextHolyStrike }
        if holyStrike {
            consumption.insert(.holyStrike)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeDouble }), !holyStrike {
            consumption.insert(.double)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeCritical }) {
            consumption.insert(.critical)
        }
        if hasActiveEffect(for: actor, in: context, where: { $0 == .nextStrikeLeech }) {
            consumption.insert(.leech)
        }
        if nextBurnBonus > 0 {
            consumption.insert(.burnBonus)
        }
        return consumption
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

    static func consumeHemorrhageIfActive(
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
                options: .reaction(),
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
            application: .afterHit,
            in: &context,
        ))
        return hemorrhageEvents
    }

    static func applyTargetedEffects(
        _ effects: [TargetedEffect],
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
        events: inout [ActionEvent],
    ) -> [String] {
        var appliedEffectLogs: [String] = []
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        for targetedEffect in effects {
            guard action.canContinue(in: context) else { break }
            if let condition = targetedEffect.condition,
               !BattleConditionEvaluator.isMet(
                   condition,
                   actor: actor,
                   abilityTarget: abilityTarget,
                   in: context,
               ) {
                continue
            }

            let effect = targetedEffect.effect
            let effectTargets = BattleTargetResolver.effectTargets(
                targetedEffect.target,
                actor: actor,
                abilityTarget: abilityTarget,
                in: context,
            )

            guard let handler = EffectHandlers.handler(for: effect.kind) else {
                logger.error("Missing effect handler for \(String(describing: effect.kind), privacy: .public)")
                continue
            }
            var didApply = false
            for effectTarget in effectTargets {
                guard action.canContinue(in: context) else { break }
                if shouldSkipEffectOnDefeatedTarget(effect, target: effectTarget, actor: actor, context: context)
                    || CombatTriggerEngine.preventsPurgedEffect(effect, on: effectTarget, in: context) {
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
                didApply = didApply || outcome.didApply
            }
            if didApply {
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
}
