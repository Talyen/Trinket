import Foundation
import os
import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    private static let logger = Logger(
        subsystem: "com.ryanmcintire.Trinket",
        category: "BattleTurnEngine",
    )

    struct DamageComponentOutcome {
        let events: [ActionEvent]
        let healthLost: Int
        let logDamageKeyword: Keyword?

        static var empty: Self {
            Self(events: [], healthLost: 0, logDamageKeyword: nil)
        }
    }

    private struct PreparedDamageComponent {
        let request: DamageRequest
        let target: Combatant
        let keyword: Keyword
        let stackPotency: Int
        let holyStrikeBurnPotency: Int
        let nextStrike: NextStrikeConsumption
        let logDamageKeyword: Keyword?
    }

    static func applyDamageComponent(
        _ component: DamageComponent,
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        guaranteedCritical: Bool,
        reservedKeywordOverride: inout Keyword?,
        context: inout BattleState,
    ) -> DamageComponentOutcome {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard action.canContinue(in: context) else { return .empty }
        let target = BattleTargetResolver.effectTarget(
            component.target, actor: actor, abilityTarget: abilityTarget, in: context,
        )
        guard context.roster.health(for: target) > 0,
              let prepared = prepareDamageComponent(
                  component, ability: ability, action: action, target: target, guaranteedCritical: guaranteedCritical,
                  reservedKeywordOverride: &reservedKeywordOverride, context: &context,
              ) else { return .empty }
        return resolveDamageComponent(prepared, ability: ability, actor: actor, context: &context)
    }

    private static func damageAmount(
        for component: DamageComponent,
        action: BattleActionContext,
        in context: BattleState,
    ) -> Int? {
        var amount: Int
        if let scaling = component.scaling {
            switch scaling {
            case let .actorBlockFraction(divisor, minimum):
                let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: action.actor))
                amount = max(minimum, block / divisor)
            }
        } else {
            amount = component.amount
        }
        if let condition = component.condition {
            if BattleConditionEvaluator.isMet(
                condition, actor: action.actor, abilityTarget: action.selectedTarget, in: context,
            ) {
                amount += component.bonusAmount
            } else if component.bonusAmount == 0 {
                return nil
            }
        }
        return amount
    }

    private static func prepareDamageComponent(
        _ component: DamageComponent,
        ability: Ability,
        action: BattleActionContext,
        target: Combatant,
        guaranteedCritical: Bool,
        reservedKeywordOverride: inout Keyword?,
        context: inout BattleState,
    ) -> PreparedDamageComponent? {
        guard var amount = damageAmount(for: component, action: action, in: context) else { return nil }
        let actor = action.actor

        let isSelfHealthCost = target.id == actor.id
        if amount > 0, !isSelfHealthCost, reservedKeywordOverride == nil {
            reservedKeywordOverride = reserveNextStrikeKeywordOverride(for: actor, in: &context)
        }
        let keywordOverride = reservedKeywordOverride.map { (keyword: $0, bonus: 0) }
            ?? activeDamageKeywordOverride(for: actor, in: context)
        var keyword = component.keyword
        var logDamageKeyword: Keyword?
        if amount > 0, !isSelfHealthCost, let override = keywordOverride {
            keyword = override.keyword
            amount += override.bonus
            if component.target == .abilityTarget {
                logDamageKeyword = override.keyword
            }
        }

        let nextBurnBonus = amount > 0 && !isSelfHealthCost && keyword == .burn
            ? activeNextBurnBonus(for: actor, in: context)
            : 0
        let nextStrike = nextStrikeConsumption(
            amount: amount, damageKeyword: keyword, isSelfHealthCost: isSelfHealthCost,
            actor: actor, nextBurnBonus: nextBurnBonus, in: context,
        )
        if nextBurnBonus > 0 {
            amount += nextBurnBonus
        }
        let holyStrikeBurnPotency = amount
        if nextStrike.contains(.holyStrike) || nextStrike.contains(.double) {
            amount *= 2
        }

        // Consume before request preparation, which may start nested reactions.
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
            amount: amount, target: target, keyword: keyword,
            sourceActorID: actor.id, options: options,
        )
        if !isSelfHealthCost {
            request.provenance = context.resolution.damageProvenance(for: actor.id)
        }
        request = UniqueCombatEngine.prepareDamage(request, in: &context)
        return PreparedDamageComponent(
            request: request, target: target, keyword: keyword, stackPotency: amount,
            holyStrikeBurnPotency: holyStrikeBurnPotency, nextStrike: nextStrike,
            logDamageKeyword: logDamageKeyword,
        )
    }

    private static func resolveDamageComponent(
        _ prepared: PreparedDamageComponent,
        ability: Ability,
        actor: Combatant,
        context: inout BattleState,
    ) -> DamageComponentOutcome {
        let damageOutcome = context.resolveDamage(prepared.request)
        let dealt = damageOutcome.healthLost
        var events = damageOutcome.events
        let componentEvent = context.nextEvent(
            kind: .abilityDamage,
            actorID: actor.id,
            actorName: actor.name,
            abilityID: ability.id,
            abilityName: ability.name,
            abilityTier: ability.tier,
            target: prepared.target,
            amount: dealt,
            keyword: prepared.keyword,
            isCritical: damageOutcome.flags.contains(.critical),
            origin: .direct,
        )
        events.append(componentEvent)

        if case .landed = damageOutcome.damageImpact {
            if prepared.nextStrike.contains(.holyStrike) {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn, potency: prepared.holyStrikeBurnPotency, to: prepared.target,
                    sourceActorID: actor.id, application: .ability,
                ))
            }
            events.append(contentsOf: applyDoTStackFromDamage(
                keyword: prepared.keyword,
                potency: prepared.keyword == .burn || prepared.keyword == .poison
                    ? dealt : prepared.stackPotency,
                to: prepared.target,
                sourceActorID: actor.id,
                isCritical: componentEvent.isCritical,
                context: &context,
            ))
        }
        return DamageComponentOutcome(
            events: events, healthLost: dealt, logDamageKeyword: prepared.logDamageKeyword,
        )
    }

    static func applyDoTStackFromDamage(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        isCritical: Bool = false,
        context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: sourceActorID)
        let criticalDurationBonus = keyword == .bleed && isCritical
            ? profile.triggers.bleedDurationFromCriticalBonus : 0
        let duration = criticalDurationBonus > 0
            ? Effect.bleedDoTTurnCount + profile.bleedDurationBonus + criticalDurationBonus : nil
        return DoTApplicator.applyDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            application: .afterHit,
            durationTurns: duration,
            in: &context,
        ) ?? []
    }

    static func activeDamageKeywordOverride(
        for actor: Combatant,
        in context: BattleState,
    ) -> (keyword: Keyword, bonus: Int)? {
        for active in context.roster.activeEffects(for: actor) {
            if case let .nextStrikeDamageKeywordOverride(keyword) = active.effect {
                return (keyword, 0)
            }
            if active.remainingTurns > 0,
               case let .damageKeywordOverride(keyword, bonus, _) = active.effect {
                return (keyword, bonus)
            }
        }
        return nil
    }

    private static func reserveNextStrikeKeywordOverride(for actor: Combatant, in context: inout BattleState) -> Keyword? {
        for active in context.roster.activeEffects(for: actor) {
            guard case let .nextStrikeDamageKeywordOverride(keyword) = active.effect else { continue }
            // Reserve before reactions or automatic plays; only this action's remaining hits share it.
            ActiveEffectMutation.removeMatching(from: actor, in: &context) { $0.kind == .nextStrikeDamageKeywordOverride }
            return keyword
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
