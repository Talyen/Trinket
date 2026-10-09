import Foundation
import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    struct DamageComponentOutcome {
        let events: [ActionEvent]
        let healthLost: Int
        let logDamageKeyword: Keyword?

        static var empty: Self {
            Self(events: [], healthLost: 0, logDamageKeyword: nil)
        }
    }

    struct NextStrikeConsumption: OptionSet {
        let rawValue: UInt8

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        static let holyStrike = Self(rawValue: 1 << 0)
        static let double = Self(rawValue: 1 << 1)
        static let critical = Self(rawValue: 1 << 2)
        static let leech = Self(rawValue: 1 << 3)
        static let burnBonus = Self(rawValue: 1 << 4)

        var consumedKinds: Set<EffectKind> {
            var kinds = Set<EffectKind>()
            if contains(.holyStrike) {
                kinds.insert(.nextHolyStrike)
            }
            if contains(.double) {
                kinds.insert(.nextStrikeDouble)
            }
            if contains(.critical) {
                kinds.insert(.nextStrikeCritical)
            }
            if contains(.leech) {
                kinds.insert(.nextStrikeLeech)
            }
            if contains(.burnBonus) {
                kinds.insert(.nextBurnBonus)
            }
            return kinds
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
    ) async -> DamageComponentOutcome {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard action.canContinue(in: context) else { return .empty }
        let target = action.target(component.target, in: context)
        guard context.roster.health(for: target) > 0,
              let prepared = prepareDamageComponent(
                  component, ability: ability, action: action, target: target, guaranteedCritical: guaranteedCritical,
                  reservedKeywordOverride: &reservedKeywordOverride, context: &context,
              ) else { return .empty }
        return await resolveDamageComponent(prepared, ability: ability, actor: actor, context: &context)
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

        let preparation = nextStrikePreparation(
            amount: amount, damageKeyword: keyword, isSelfHealthCost: isSelfHealthCost,
            effects: context.roster.activeEffects(for: actor),
        )
        let nextStrike = preparation.consumption
        amount += preparation.burnBonus
        let holyStrikeBurnPotency = amount
        if nextStrike.contains(.holyStrike) || nextStrike.contains(.double) {
            amount *= 2
        }

        // Consume before request preparation, which may start nested reactions.
        let consumedKinds = nextStrike.consumedKinds
        ActiveEffectMutation.removeMatching(from: actor, in: &context) { consumedKinds.contains($0.kind) }
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
    ) async -> DamageComponentOutcome {
        let damageOutcome = await context.resolveDamage(prepared.request)
        let dealt = damageOutcome.healthLost
        var events = damageOutcome.events
        let componentEvent = context.nextEvent(
            kind: .abilityDamage,
            actionID: context.resolution.actionID,
            source: .init(actor),
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
                await events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn, potency: prepared.holyStrikeBurnPotency, to: prepared.target,
                    sourceActorID: actor.id, application: .ability,
                ))
            }
            await events.append(contentsOf: applyDoTStackFromDamage(
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
    ) async -> [ActionEvent] {
        let profile = context.modifiers(for: sourceActorID)
        let criticalDurationBonus = keyword == .bleed && isCritical
            ? profile.triggers.bleedDurationFromCriticalBonus : 0
        let duration = criticalDurationBonus > 0
            ? Effect.bleedDoTTurnCount + profile.bleedDurationBonus + criticalDurationBonus : nil
        return await DoTApplicator.applyDoT(
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

    private static func nextStrikePreparation(
        amount: Int,
        damageKeyword: Keyword,
        isSelfHealthCost: Bool,
        effects: [ActiveEffect],
    ) -> (consumption: NextStrikeConsumption, burnBonus: Int) {
        guard amount > 0, !isSelfHealthCost else { return ([], 0) }
        var consumption: NextStrikeConsumption = []
        var burnBonus = 0
        for active in effects {
            switch active.effect {
            case .nextHolyStrike where damageKeyword == .holy:
                consumption.insert(.holyStrike)
            case .nextStrikeDouble:
                consumption.insert(.double)
            case .nextStrikeCritical:
                consumption.insert(.critical)
            case .nextStrikeLeech:
                consumption.insert(.leech)
            case let .nextBurnBonus(bonus) where damageKeyword == .burn:
                burnBonus += bonus
            default:
                break
            }
        }
        // Holy Strike takes priority; the ordinary double remains ready for a later hit.
        if consumption.contains(.holyStrike) {
            consumption.remove(.double)
        }
        if burnBonus > 0 {
            consumption.insert(.burnBonus)
        }
        return (consumption, max(0, burnBonus))
    }

    static func consumeHemorrhageIfActive(
        for actor: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
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
        ActiveEffectMutation.removeMatching(from: actor, in: &context) { $0.kind == .hemorrhage }
        let casterID = sourceActorID ?? actor.id
        let hemorrhageOutcome = await context.resolveDamage(
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
                source: .init(actor),
                abilityName: "Hemorrhage",
                target: actor,
                amount: hemorrhageOutcome.healthLost,
                keyword: .bleed,
            ))
        }
        await hemorrhageEvents.append(contentsOf: DoTApplicator.applyBleed(
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
    ) async -> [String] {
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
            let effectTargets = action.targets(targetedEffect.target, in: context)

            let handler = EffectHandlers.handler(for: effect.kind)
            var didApply = false
            var grantedGold = 0
            var restoredMana = 0
            for effectTarget in effectTargets {
                guard action.canContinue(in: context) else { break }
                guard context.roster.health(for: effectTarget) > 0 || effect.canApplyToDefeatedTarget,
                      !CombatTriggerEngine.preventsPurgedEffect(effect, on: effectTarget, in: context)
                else { continue }
                let outcome = await handler.apply(
                    effect,
                    ability: ability,
                    source: actor,
                    target: effectTarget,
                    in: &context,
                )
                events.append(contentsOf: outcome.events)
                grantedGold += directResourceGain(by: outcome, keyword: .gold, ability: ability)
                restoredMana += directResourceGain(by: outcome, keyword: .mana, ability: ability)
                didApply = didApply || outcome.didApply
            }
            if didApply, let summary = appliedEffectSummary(
                effect, ability: ability, grantedGold: grantedGold, restoredMana: restoredMana,
            ) {
                appliedEffectLogs.append(summary)
            }
        }
        return appliedEffectLogs
    }

    private static func directResourceGain(by outcome: EffectApplyOutcome, keyword: Keyword, ability: Ability) -> Int {
        // The handler emits its gain before any talent reactions,
        // including when automatic play changes its event origin.
        guard let restoration = outcome.events.first,
              restoration.effectKind == .resourceGain, restoration.keyword == keyword,
              restoration.abilityName == ability.name else { return 0 }
        return restoration.amount
    }

    private static func appliedEffectSummary(
        _ effect: Effect, ability: Ability, grantedGold: Int, restoredMana: Int,
    ) -> String? {
        switch effect {
        case .resourceGain(.gold, _): "\(ability.stealsGold ? "steal" : "gain") \(grantedGold) Gold"
        case .resourceGain(.mana, _): restoredMana > 0 ? "restore \(restoredMana) Mana" : nil
        default: effect.summary
        }
    }
}
