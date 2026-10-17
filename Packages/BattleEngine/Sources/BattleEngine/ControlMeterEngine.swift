import Foundation
import TrinketContent
import TrinketCore

package struct ControlMeterOutcome {
    let didApply: Bool
    let didTrigger: Bool
    static let empty = Self(didApply: false, didTrigger: false)
}

package enum ControlMeterEngine {
    @discardableResult
    package static func applyMeterCharge(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        applyFightPacing: Bool = true,
        preservingTriggeredStatus: Bool = false,
        setupHealthDamage: Int = 0,
        in context: inout BattleState,
    ) async -> ControlMeterOutcome {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return .empty }
        if keyword == .stun || keyword == .freeze,
           context.modifiers(for: combatant.id).triggers.blockedControlPrevention,
           DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0 {
            return .empty
        }
        if context.roster.hasControlStatus(for: combatant, keyword: keyword) {
            return .empty
        }
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        guard pacedAmount > 0 else { return .empty }

        let threshold = threshold(for: combatant, in: context)
        let adjustedAmount = preservingTriggeredStatus ? threshold : adjustedCharge(
            pacedAmount, keyword: keyword, to: combatant, sourceActorID: sourceActorID, in: context,
        )
        guard adjustedAmount > 0 else { return .empty }

        let effectiveThreshold: Int = if keyword == .stun, combatant.role == .enemy, let sourceActorID,
                                         context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent > 0 {
            CombatRounding.scaled(
                threshold,
                multiplier: 1 - min(1, context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent),
            )
        } else {
            threshold
        }
        guard !context.interceptDebuff(
            .controlMeter(keyword, adjustedAmount, effectiveThreshold),
            on: combatant,
        ) else { return .empty }
        let existingAmount = meter(keyword, on: combatant, in: context)?.effect.controlMeterValues?.amount ?? 0
        let newAmount = min(SaturatedArithmetic.saturatingAdd(existingAmount, adjustedAmount), effectiveThreshold)
        let triggered = newAmount >= effectiveThreshold
        storeMeter(
            keyword, amount: triggered ? threshold : newAmount,
            threshold: triggered ? threshold : effectiveThreshold,
            on: combatant, sourceActorID: sourceActorID, in: &context,
        )
        if triggered {
            await thresholdReached(
                keyword, on: combatant, sourceActorID: sourceActorID,
                triggeredAmount: effectiveThreshold, setupHealthDamage: setupHealthDamage, in: &context,
            )
            await ElementalReactionEngine.finishControl(in: &context)
        }
        return ControlMeterOutcome(didApply: true, didTrigger: triggered)
    }

    package static func threshold(for combatant: Combatant, in context: BattleState) -> Int {
        let maxHealth = context.roster.maxHealth(for: combatant)
        return max(1, CombatRounding.rounded(Double(maxHealth) * 0.20))
    }

    // swiftlint:disable:next function_body_length - control rewards follow the committed status in their existing order
    private static func thresholdReached(
        _ keyword: Keyword,
        on combatant: Combatant,
        sourceActorID: String?,
        triggeredAmount: Int,
        setupHealthDamage: Int = 0,
        in context: inout BattleState,
    ) async {
        context.resolution.controlDepth += 1
        defer { context.resolution.controlDepth -= 1 }
        ElementalReactionEngine.prepareControl(
            keyword, target: combatant, healthDamage: setupHealthDamage, sourceID: sourceActorID, in: &context,
        )
        if keyword == .stun {
            UniqueCombatEngine.retainStun(
                triggeredAmount,
                on: combatant,
                sourceActorID: sourceActorID,
                in: &context,
            )
        }
        if keyword == .freeze || keyword == .stun,
           let owner = context.roster.participant(for: combatant),
           owner.isPartyMember {
            BattleCardCombatEngine.recycleControlledOwnerCards(for: owner, context: &context)
        }
        if keyword == .freeze, let sourceActorID {
            let chance = context.modifiers(for: sourceActorID).triggers.freezeExtendChancePercent
                + Double(context.modifiers(for: sourceActorID).triggers.freezeExtraActionSkips) * 0.20
            applyExtendControlChance(chance, keyword: keyword, to: combatant, in: &context)
        }
        if keyword == .stun, let sourceActorID {
            let chance = context.modifiers(for: sourceActorID).triggers.stunExtendChancePercent
                + Double(context.modifiers(for: sourceActorID).triggers.enemyStunExtraActionSkips) * 0.20
            applyExtendControlChance(chance, keyword: keyword, to: combatant, in: &context)
            if context.modifiers(for: sourceActorID).triggers.stunExtendVsBurning,
               context.roster.hasAffliction(.burn, on: combatant) {
                applyExtendControlChance(1, keyword: keyword, to: combatant, in: &context)
            }
        }

        let abilityName = keyword.statusAlias ?? keyword.rawValue
        context.nextEvent(
            kind: .effect(.controlTriggered),
            source: context.eventSource(actorID: sourceActorID, fallback: combatant),
            abilityName: abilityName,
            target: combatant,
            amount: 0,
            keyword: keyword,
        )

        if keyword == .stun, combatant.id == context.roster.enemy.id {
            await CombatTriggerEngine.afterEnemyStunned(sourceActorID: sourceActorID, in: &context)
        }
        if keyword == .freeze, combatant.id == context.roster.enemy.id {
            await CombatTriggerEngine.afterEnemyFrozen(sourceActorID: sourceActorID, in: &context)
        }
        if keyword == .freeze {
            frozenOpponentBlock(on: combatant, in: &context)
        }
        if keyword == .freeze,
           combatant.role == .enemy,
           let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID), source.isAlive,
           context.modifiers(for: sourceActorID).triggers.onFreezeEnemyGainManaEqualBlock {
            let owner = source.combatant
            let currentBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: owner))
            if currentBlock > 0 {
                await context.restoreManaEmitting(currentBlock, to: owner, abilityName: "Rimeheart")
            }
        }
        if keyword == .stun,
           combatant.role == .enemy,
           let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID), source.isAlive,
           context.modifiers(for: sourceActorID).triggers.onStunEnemyGainBlock > 0,
           context.roster.health(for: combatant) > 0 {
            context.applyBlockGain(
                context.modifiers(for: sourceActorID).triggers.onStunEnemyGainBlock,
                to: source.combatant,
                source: source.combatant,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .onStunEnemyGainBlock,
                    for: source.combatant,
                    fallback: "Stalwart Oath",
                    in: context,
                ),
            )
        }
        if keyword == .stun,
           combatant.role == .enemy,
           let sourceActorID,
           context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn > 0,
           context.roster.health(for: combatant) > 0 {
            await context.applyDecayingDoT(
                keyword: .burn,
                potency: context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn,
                to: combatant,
                sourceActorID: sourceActorID,
                application: .reaction,
            )
        }
    }

    private static func frozenOpponentBlock(
        on target: Combatant,
        in context: inout BattleState,
    ) {
        let observers = BattleActionContext(actor: target, in: context).opponents(in: context)
        for actor in observers {
            let amount = context.modifiers(for: actor.id).triggers.onEnemyFrozenGainBlock
            guard context.health(of: actor) > 0, amount > 0 else { continue }
            context.applyBlockGain(
                amount, to: actor, source: actor,
                abilityName: context.modifiers(for: actor.id).triggerAbilityName(
                    .onEnemyFrozenGainBlock, fallback: "Glacial Barrier",
                ),
            )
        }
    }

    private static func applyExtendControlChance(
        _ chance: Double,
        keyword: Keyword,
        to combatant: Combatant,
        in context: inout BattleState,
    ) {
        guard chance.isFinite, chance > 0, let status = context.roster.activeEffects(for: combatant).first(where: {
            $0.keyword == keyword && $0.isAwaitingActionSkip
        }) else { return }
        let whole = chance.rounded(.down)
        var skips = SaturatedArithmetic.rounded(whole)
        let fraction = chance - whole
        if fraction > 0, BattleChance.succeeds(probability: fraction, using: &context.rng) {
            skips = SaturatedArithmetic.saturatingAdd(skips, 1)
        }
        if skips > 0 {
            context.additionalControlSkipsByEffectID[status.id] = SaturatedArithmetic.saturatingAdd(
                context.additionalControlSkipsByEffectID[status.id, default: 0], skips,
            )
        }
    }

    private static func meter(_ keyword: Keyword, on combatant: Combatant, in context: BattleState) -> ActiveEffect? {
        context.roster.activeEffects(for: combatant).first { active in
            active.effect.kind == .controlMeter && active.keyword == keyword
        }
    }

    private static func storeMeter(
        _ keyword: Keyword, amount: Int, threshold: Int,
        on combatant: Combatant, sourceActorID: String?, in context: inout BattleState,
    ) {
        let existing = meter(keyword, on: combatant, in: context)
        let effectID = existing?.id ?? context.consumeNextEffectID()
        context.roster.mutateEffects(for: combatant) { effects in
            let buildup = Effect.controlMeter(keyword, amount, threshold)
            if let index = effects.firstIndex(where: { $0.id == effectID }) {
                effects[index].effect = buildup
            } else {
                effects.append(ActiveEffect(id: effectID, effect: buildup, remainingTurns: 0, sourceActorID: sourceActorID))
            }
        }
    }
}

extension ControlMeterEngine {
    private static func adjustedCharge(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: BattleState,
    ) -> Int {
        var adjustedAmount = amount
        if keyword == .freeze, combatant.role == .enemy, let sourceActorID {
            let multiplier = context.modifiers(for: sourceActorID).triggers.freezeBuildupMultiplier
            if multiplier > 1 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: multiplier)
            }
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID,
           context.roster.hasAffliction(.poison, on: combatant) {
            let sourceMultiplier = context.modifiers(for: sourceActorID).triggers.poisonedEnemyStunBuildupMultiplier
            let heroMultiplier = context.roster.hero.isAlive
                ? context.heroModifiers.triggers.poisonedEnemyStunBuildupMultiplier : 1
            let multiplier = max(sourceMultiplier, heroMultiplier)
            if multiplier > 1 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: multiplier)
            }
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           source.isBelowHalfHealth {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount,
                multiplier: context.modifiers(for: sourceActorID).triggers.stunBuildupBelowHalfMultiplier,
            )
        }
        if keyword == .stun, combatant.role == .enemy, let sourceActorID {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount, multiplier: context.modifiers(for: sourceActorID).triggers.stunBuildupMultiplier,
            )
        }
        if keyword == .freeze, combatant.role == .enemy, let sourceActorID,
           context.resolution.actionTalents(for: sourceActorID)?.empoweredByMana == true {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount,
                multiplier: context.modifiers(for: sourceActorID).triggers.manaEmpowerFreezeBuildupMultiplier,
            )
        }
        if keyword == .stun || keyword == .freeze {
            let targetTriggers = context.modifiers(for: combatant.id).triggers
            let steadfastResistance = targetTriggers.blockedControlBurnResistance > 0
                && DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0
                ? targetTriggers.blockedControlBurnResistance
                : 0
            let lichboneResistance = keyword == .stun ? targetTriggers.afflictionResistance : 0
            let partyResistance: Double = switch combatant.role {
            case .hero, .companion: 0.25
            case .enemy: 0
            }
            let controlResistance = 1 - (1 - partyResistance) * (1 - steadfastResistance) * (1 - lichboneResistance)
            if controlResistance > 0 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: 1 - min(1, controlResistance))
            }
        }
        return adjustedAmount
    }

    static func multiplyBuildup(
        _ factor: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        abilityID: String = "",
        abilityName: String,
        in context: inout BattleState,
    ) async -> Bool {
        guard factor > 1,
              keyword == .freeze,
              context.roster.health(for: combatant) > 0,
              !context.roster.hasControlStatus(for: combatant, keyword: keyword)
        else {
            return false
        }
        guard let existing = meter(keyword, on: combatant, in: context),
              let values = existing.effect.controlMeterValues,
              values.amount > 0, values.threshold > values.amount,
              !isProtected(existing.effect, on: combatant, in: context) else { return false }
        let currentAmount = values.amount
        let threshold = values.threshold

        let newAmount = min(SaturatedArithmetic.saturatingMul(currentAmount, factor), threshold)
        guard newAmount > currentAmount else { return false }

        context.nextEvent(
            kind: .effect(.dotAmplified),
            source: context.eventSource(actorID: sourceActorID, fallback: combatant),
            abilityID: abilityID, abilityName: abilityName,
            target: combatant,
            amount: newAmount - currentAmount,
            keyword: keyword,
            origin: .direct,
        )

        storeMeter(keyword, amount: newAmount, threshold: threshold, on: combatant, sourceActorID: sourceActorID, in: &context)
        if newAmount >= threshold {
            await thresholdReached(keyword, on: combatant, sourceActorID: sourceActorID, triggeredAmount: newAmount, in: &context)
            await ElementalReactionEngine.finishControl(in: &context)
        }
        return true
    }

    private static func isProtected(_ effect: Effect, on combatant: Combatant, in context: BattleState) -> Bool {
        let blocked = context.modifiers(for: combatant.id).triggers.blockedControlPrevention
            && DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0
        return blocked || CombatTriggerEngine.preventsDebuff(effect, on: combatant, in: context)
    }
}
