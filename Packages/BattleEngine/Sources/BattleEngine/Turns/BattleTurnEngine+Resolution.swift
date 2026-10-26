import Foundation
import TrinketContent
import TrinketCore

extension BattleTurnEngine {
    struct DamageComponentOutcome {
        let healthLost: Int
        let logDamageKeyword: Keyword?
        var elementalSettlement: CombatOutcome?

        static var empty: Self {
            Self(healthLost: 0, logDamageKeyword: nil)
        }
    }

    private struct NextStrikePreparation: OptionSet {
        let rawValue: UInt8

        static let holy = Self(rawValue: 1 << 0)
        static let doubleDamage = Self(rawValue: 1 << 1)
        static let critical = Self(rawValue: 1 << 2)
        static let leech = Self(rawValue: 1 << 3)
        static let burnBonus = Self(rawValue: 1 << 4)

        func consumes(_ effect: Effect) -> Bool {
            switch effect {
            case .nextHolyStrike: contains(.holy)
            case .nextStrikeDouble: contains(.doubleDamage)
            case .nextStrikeCritical: contains(.critical)
            case .nextStrikeLeech: contains(.leech)
            case .nextBurnBonus: contains(.burnBonus)
            default: false
            }
        }
    }

    private struct PreparedDamageComponent {
        let request: DamageRequest
        let target: Combatant
        let keyword: Keyword
        let stackPotency: Int
        let holyStrikeBurnPotency: Int
        let nextStrike: NextStrikePreparation
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

    private static func prepareDamageComponent(
        _ component: DamageComponent,
        ability: Ability,
        action: BattleActionContext,
        target: Combatant,
        guaranteedCritical: Bool,
        reservedKeywordOverride: inout Keyword?,
        context: inout BattleState,
    ) -> PreparedDamageComponent? {
        guard var amount = BattleDamageRules.amount(component, action: action, in: context) else { return nil }
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
            amount = SaturatedArithmetic.saturatingAdd(amount, override.bonus)
            if component.target == .abilityTarget {
                logDamageKeyword = override.keyword
            }
        }

        let preparation = nextStrikePreparation(
            amount: amount, damageKeyword: keyword, isSelfHealthCost: isSelfHealthCost,
            effects: context.roster.activeEffects(for: actor),
        )
        let nextStrike = preparation.consumption
        amount = SaturatedArithmetic.saturatingAdd(amount, preparation.burnBonus)
        let holyStrikeBurnPotency = amount
        if nextStrike.contains(.holy) || nextStrike.contains(.doubleDamage) {
            amount = SaturatedArithmetic.saturatingMul(amount, 2)
        }

        // Consume before request preparation, which may start nested reactions.
        if !nextStrike.isEmpty {
            ActiveEffectMutation.removeMatching(from: actor, in: &context) { nextStrike.consumes($0) }
        }
        let options: DamageOperation = isSelfHealthCost
            ? .healthCost
            : .attack(
                tier: ability.tier,
                origin: context.resolution.attackOrigin,
                abilityCriticalChanceBonus: ability.criticalChanceBonus,
                guaranteedCriticalIfEnemyBuffed: ability.guaranteedCriticalIfEnemyBuffed,
                guaranteedCritical: guaranteedCritical || nextStrike.contains(.critical),
                abilityHasLeech: ability.hasLeech || component.hasLeech || nextStrike.contains(.leech),
            )
        var request = DamageRequest(
            amount: amount, target: target, keyword: keyword,
            sourceActorID: actor.id, options: options,
        )
        if !isSelfHealthCost {
            request.provenance = context.resolution.damageProvenance(for: actor.id)
        }
        request.options = request.options.settlingElementalAfterAttachment()
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
        if damageOutcome.isCritical {
            context.resolution.recordCardAttackCritical(by: actor.id)
        }
        let dealt = damageOutcome.healthLost

        context.nextEvent(
            kind: .abilityDamage,
            actionID: context.resolution.actionID,
            source: .init(actor),
            abilityID: ability.id,
            abilityName: ability.name,
            abilityTier: ability.tier,
            target: prepared.target,
            amount: dealt,
            keyword: prepared.keyword,
            isCritical: damageOutcome.isCritical,
            origin: .direct,
        )

        if actor.role == .enemy, prepared.target.role != .enemy,
           prepared.request.options.isPrimaryAttack, prepared.request.amount > 0 {
            await EnemyTraitEngine.afterEnemyHit(landed: !damageOutcome.isDodged, context: &context)
        }

        if case .landed = damageOutcome.damageImpact {
            if prepared.nextStrike.contains(.holy) {
                await context.applyDecayingDoT(
                    keyword: .burn, potency: prepared.holyStrikeBurnPotency, to: prepared.target,
                    sourceActorID: actor.id, application: .ability,
                )
            }
            await applyDoTStackFromDamage(
                keyword: prepared.keyword,
                potency: prepared.keyword == .burn || prepared.keyword == .poison
                    ? dealt : prepared.stackPotency,
                to: prepared.target,
                sourceActorID: actor.id,
                isCritical: damageOutcome.isCritical,
                context: &context,
            )
        }
        var settlement = damageOutcome
        if let hit = settlement.elementalHit {
            settlement.elementalHit = ElementalReactionEngine.captureAttachment(hit, outcome: damageOutcome, in: &context)
        }
        return DamageComponentOutcome(
            healthLost: dealt, logDamageKeyword: prepared.logDamageKeyword,
            elementalSettlement: settlement.elementalHit == nil ? nil : settlement,
        )
    }

    static func applyDoTStackFromDamage(
        keyword: Keyword,
        potency: Int,
        to target: Combatant,
        sourceActorID: String,
        isCritical: Bool = false,
        context: inout BattleState,
    ) async {
        guard keyword == .burn || keyword == .poison || keyword == .bleed else { return }
        let profile = context.modifiers(for: sourceActorID)
        let criticalDurationBonus = keyword == .bleed && isCritical
            ? profile.triggers.bleedDurationFromCriticalBonus : 0
        let duration = criticalDurationBonus > 0
            ? SaturatedArithmetic.saturatingAdd(
                SaturatedArithmetic.saturatingAdd(Effect.bleedDoTTurnCount, profile.bleedDurationBonus),
                criticalDurationBonus,
            ) : nil
        await DoTApplicator.applyDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            application: .afterHit,
            durationTurns: duration,
            in: &context,
        )
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
    ) -> (consumption: NextStrikePreparation, burnBonus: Int) {
        guard amount > 0, !isSelfHealthCost else { return ([], 0) }
        var consumption: NextStrikePreparation = []
        var burnBonus = 0
        for active in effects {
            switch active.effect {
            case .nextHolyStrike where damageKeyword == .holy:
                consumption.insert(.holy)
            case .nextStrikeDouble:
                consumption.insert(.doubleDamage)
            case .nextStrikeCritical:
                consumption.insert(.critical)
            case .nextStrikeLeech:
                consumption.insert(.leech)
            case let .nextBurnBonus(bonus) where damageKeyword == .burn:
                burnBonus = SaturatedArithmetic.saturatingAdd(burnBonus, bonus)
            default:
                break
            }
        }
        // Holy Strike takes priority; the ordinary double remains ready for a later hit.
        if consumption.contains(.holy) {
            consumption.remove(.doubleDamage)
        }
        if burnBonus > 0 {
            consumption.insert(.burnBonus)
        }
        return (consumption, max(0, burnBonus))
    }

    static func consumeHemorrhageIfActive(
        for actor: Combatant,
        in context: inout BattleState,
    ) async {
        var hemorrhageDamage: Int?
        var sourceActorID: String?
        for active in context.roster.activeEffects(for: actor) {
            if case let .hemorrhage(damage) = active.effect {
                hemorrhageDamage = damage
                sourceActorID = active.sourceActorID
                break
            }
        }
        guard let hemorrhageDamage else { return }
        ActiveEffectMutation.removeMatching(from: actor, in: &context) { $0.kind == .hemorrhage }
        let casterID = sourceActorID ?? actor.id
        let hemorrhageOutcome = await context.dealReactionDamage(hemorrhageDamage, to: actor, keyword: .bleed, sourceActorID: casterID)

        if hemorrhageOutcome.healthLost > 0 {
            context.nextEvent(
                kind: .effect(.hemorrhageTriggered),
                source: .init(actor),
                abilityName: "Hemorrhage",
                target: actor,
                amount: hemorrhageOutcome.healthLost,
                keyword: .bleed,
            )
        }
        await DoTApplicator.applyBleed(potency: hemorrhageDamage, to: actor, sourceActorID: casterID, application: .afterHit, in: &context)
    }

    static func applyTargetedEffect(
        _ targeted: TargetedEffect,
        ability: Ability,
        actor: Combatant,
        abilityTarget: Combatant,
        context: inout BattleState,
    ) async -> Effect? {
        let action = BattleActionContext(actor: actor, selectedTarget: abilityTarget)
        guard action.canContinue(in: context) else { return nil }
        if let condition = targeted.condition,
           !BattleConditionEvaluator.isMet(condition, actor: actor, abilityTarget: abilityTarget, in: context) {
            return nil
        }

        guard BattleChance.succeeds(probability: targeted.chance, using: &context.rng) else { return nil }
        let effect = targeted.effect
        var didApply = false
        var grantedGold = 0
        var restoredMana = 0
        for effectTarget in action.targets(targeted.target, in: context) {
            guard action.canContinue(in: context) else { break }
            guard context.roster.health(for: effectTarget) > 0 || effect.canApplyToDefeatedTarget,
                  !CombatTriggerEngine.preventsPurgedEffect(effect, on: effectTarget, in: context)
            else { continue }
            let outcome = await EffectApplication(
                effect: effect, ability: ability, source: actor, target: effectTarget,
            ).apply(in: &context)
            grantedGold = SaturatedArithmetic.saturatingAdd(grantedGold, outcome.grantedGold)
            restoredMana = SaturatedArithmetic.saturatingAdd(restoredMana, outcome.restoredMana)
            didApply = didApply || outcome.didApply
        }
        guard didApply else { return nil }
        switch effect {
        case .resourceGain(.gold, _): return .resourceGain(.gold, grantedGold)
        case .resourceGain(.mana, _): return restoredMana > 0 ? .resourceGain(.mana, restoredMana) : nil
        default: return effect
        }
    }
}
