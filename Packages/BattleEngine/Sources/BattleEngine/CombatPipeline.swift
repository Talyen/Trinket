import Foundation
import TrinketCore
import TrinketContent

/// Damage, healing, leech, and prevention-buildup rules.
public enum CombatPipeline {
    public static func resolveDamage(
        _ request: DamageRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }

        var state = DamageResolutionState(
            amount: request.amount,
            combatant: request.target,
            sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword,
            applyStatBonus: request.options.applyStatBonus,
            applyItemBonus: request.options.applyItemBonus,
            applyDodge: request.options.applyDodge
        )

        DodgeGateStep().apply(to: &state, in: &context)
        if state.isDodged { return CombatOutcome.fromDamage(state: state) }

        DamageBonusStep().apply(to: &state, in: &context)
        ShieldAbsorptionStep().apply(to: &state, in: &context)
        MitigationStep().apply(to: &state, in: &context)
        ItemReductionStep().apply(to: &state, in: &context)
        TakeDamageStep().apply(to: &state, in: &context)
        LeechStep().apply(to: &state, in: &context)
        PreventionBuildupStep().apply(to: &state, in: &context)

        return CombatOutcome.fromDamage(state: state)
    }

    public static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(request.amount + bonus) }
        _ = request.logAs
        return CombatOutcome(healthDelta: restored, events: [], flags: [])
    }

    public static func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> (healthLost: Int, events: [ActionEvent]) {
        let outcome = resolveDamage(
            .doTTick(
                amount: amount,
                target: combatant,
                keyword: keyword,
                sourceActorID: sourceActorID
            ),
            in: &context
        )
        return (outcome.healthLost, outcome.events)
    }

    public static func applyPreventionBuildup(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return [] }
        if context.roster.hasActivePrevention(for: combatant) { return [] }

        let threshold = preventionThreshold(for: combatant, in: context)
        var currentEffects = context.roster.activeEffects(for: combatant)
        let existingIndex = currentEffects.firstIndex { activeEffect in
            if case let .preventionBuildup(k, _, _) = activeEffect.effect, k == keyword { return true }
            return false
        }
        let existingAmount = existingBuildupAmount(at: existingIndex, in: currentEffects)
        let newAmount = min(existingAmount + amount, threshold)

        if newAmount >= threshold {
            return applyPreventionThresholdReached(
                PreventionThresholdContext(
                    keyword: keyword,
                    combatant: combatant,
                    sourceActorID: sourceActorID,
                    existingIndex: existingIndex
                ),
                currentEffects: &currentEffects,
                in: &context
            )
        }

        updatePreventionBuildup(
            PreventionBuildupUpdate(
                keyword: keyword,
                newAmount: newAmount,
                threshold: threshold,
                combatant: combatant,
                sourceActorID: sourceActorID,
                existingIndex: existingIndex
            ),
            currentEffects: &currentEffects,
            in: &context
        )
        return []
    }

    private static func preventionThreshold(for combatant: Combatant, in context: BattleEngineContext) -> Int {
        combatant.primaryStats.preventionThreshold(
            baseMaxHealth: context.roster.maxHealth(for: combatant)
        )
    }

    private static func existingBuildupAmount(
        at existingIndex: Int?,
        in currentEffects: [ActiveEffect]
    ) -> Int {
        guard let existingIndex,
              case let .preventionBuildup(_, amount, _) = currentEffects[existingIndex].effect
        else { return 0 }
        return amount
    }

    private struct PreventionThresholdContext {
        let keyword: Keyword
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
    }

    private static func applyPreventionThresholdReached(
        _ thresholdContext: PreventionThresholdContext,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let keyword = thresholdContext.keyword
        let combatant = thresholdContext.combatant
        let sourceActorID = thresholdContext.sourceActorID
        let existingIndex = thresholdContext.existingIndex

        if let existingIndex {
            currentEffects.remove(at: existingIndex)
        }
        let prevention = Effect.prevention(keyword, 1)
        let activeEffect = ActiveEffect(
            id: context.nextEffectID,
            effect: prevention,
            remainingTicks: 1,
            sourceActorID: sourceActorID
        )
        context.nextEffectID += 1
        currentEffects.append(activeEffect)
        context.roster.setActiveEffects(currentEffects, for: combatant)

        let actorName: String
        if let sourceActorID, let source = context.roster.combatant(for: sourceActorID) {
            actorName = source.name
        } else {
            actorName = combatant.name
        }
        let abilityName = keyword.statusAlias ?? keyword.rawValue
        return [
            context.nextEvent(
                kind: .effect,
                effectKind: .preventionTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword,
                appliedEffectSummaries: [],
                milestone: nil
            )
        ]
    }

    private struct PreventionBuildupUpdate {
        let keyword: Keyword
        let newAmount: Int
        let threshold: Int
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
    }

    private static func updatePreventionBuildup(
        _ update: PreventionBuildupUpdate,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleEngineContext
    ) {
        let buildup = Effect.preventionBuildup(update.keyword, update.newAmount, update.threshold)
        if let existingIndex = update.existingIndex {
            currentEffects[existingIndex] = ActiveEffect(
                id: currentEffects[existingIndex].id,
                effect: buildup,
                remainingTicks: currentEffects[existingIndex].remainingTicks,
                sourceActorID: currentEffects[existingIndex].sourceActorID
            )
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.nextEffectID,
                    effect: buildup,
                    remainingTicks: 0,
                    sourceActorID: update.sourceActorID
                )
            )
            context.nextEffectID += 1
        }
        context.roster.setActiveEffects(currentEffects, for: update.combatant)
    }

    public static func applyLeechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard damage > 0, let actor = context.roster.combatant(for: sourceActorID) else { return [] }
        let actorCombatant = actor.combatant

        let leechPct = context.roster.activeEffects(for: actorCombatant).reduce(0.0) { sum, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect { return sum + percent }
            return sum
        }
        guard leechPct > 0 else { return [] }

        let wisdomPercent = Double(actorCombatant.primaryStats.wisdom) * 0.001
        let totalPct = leechPct + wisdomPercent
        var restored = Int(ceil(Double(damage) * totalPct))
        restored += context.modifiers(for: sourceActorID).leechHealingBonus
        guard restored > 0 else { return [] }

        applyHeal(
            restored,
            to: actorCombatant,
            sourceActorID: nil,
            in: &context
        )
        return [
            context.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: actorCombatant,
                amount: restored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil
            )
        ]
    }

    public static func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        in context: inout BattleEngineContext
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        let outcome = resolveDamage(
            DamageRequest(
                amount: amount,
                target: combatant,
                keyword: damageKeyword,
                sourceActorID: sourceActorID,
                options: DamageOptions(
                    applyStatBonus: applyStatBonus,
                    applyItemBonus: applyItemBonus,
                    applyDodge: applyDodge
                )
            ),
            in: &context
        )
        return (outcome.healthLost, outcome.events)
    }

    public static func applyHeal(
        _ amount: Int,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) {
        _ = resolveHeal(
            HealRequest(amount: amount, target: combatant, sourceActorID: sourceActorID),
            in: &context
        )
    }
}
