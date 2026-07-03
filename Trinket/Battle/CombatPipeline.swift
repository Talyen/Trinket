import Foundation

/// Damage, healing, leech, and prevention-buildup rules.
enum CombatPipeline {
    private static func maxHealth(for combatant: Combatant) -> Int {
        combatant.maxHealth + combatant.primaryStats.toughness
    }

    static func applyDoTDamage(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> (healthLost: Int, events: [ActionEvent]) {
        guard amount > 0 else { return (0, []) }

        let (healthLost, damageEvents) = applyDamage(
            amount,
            to: combatant,
            damageKeyword: keyword,
            sourceActorID: sourceActorID,
            applyStatBonus: false,
            applyDodge: false,
            in: &context
        )
        var events = damageEvents
        if healthLost > 0, let sourceActorID {
            events.append(contentsOf: applyLeechFromDamage(healthLost, sourceActorID: sourceActorID, in: &context))
        }
        return (healthLost, events)
    }

    static func applyPreventionBuildup(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return [] }
        if context.roster.hasActivePrevention(for: combatant) { return [] }

        let baseThreshold = Double(maxHealth(for: combatant)) * 0.20
        let agilityResist = 1.0 + Double(combatant.primaryStats.agility) * 0.01
        let threshold = max(1, Int(ceil(baseThreshold * agilityResist)))
        var currentEffects = context.roster.activeEffects(for: combatant)

        let existingIndex = currentEffects.firstIndex { ae in
            if case let .preventionBuildup(k, _, _) = ae.effect, k == keyword { return true }
            return false
        }
        let existingAmount: Int = {
            guard let existingIndex,
                  case let .preventionBuildup(_, amt, _) = currentEffects[existingIndex].effect
            else { return 0 }
            return amt
        }()

        let newAmount = min(existingAmount + amount, threshold)
        var events: [ActionEvent] = []

        if newAmount >= threshold {
            if let existingIndex {
                currentEffects.remove(at: existingIndex)
            }
            let prevention = Effect.prevention(keyword, 1)
            let ae = ActiveEffect(
                id: context.nextEffectID,
                effect: prevention,
                remainingTicks: 1,
                sourceActorID: sourceActorID
            )
            context.nextEffectID += 1
            currentEffects.append(ae)
            context.roster.setActiveEffects(currentEffects, for: combatant)

            let actorName: String
            if let sourceActorID, let source = context.roster.combatant(for: sourceActorID) {
                actorName = source.name
            } else {
                actorName = combatant.name
            }
            let abilityName = keyword.statusAlias ?? keyword.rawValue
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .preventionTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword,
                appliedEffectSummaries: [],
                milestone: nil
            ))
        } else {
            let buildup = Effect.preventionBuildup(keyword, newAmount, threshold)
            if let existingIndex {
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
                        sourceActorID: sourceActorID
                    )
                )
                context.nextEffectID += 1
            }
            context.roster.setActiveEffects(currentEffects, for: combatant)
        }

        return events
    }

    static func applyLeechFromDamage(
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

        applyHeal(restored, to: actorCombatant, sourceActorID: nil, in: &context)
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

    static func applyDamage(
        _ amount: Int,
        to combatant: Combatant,
        damageKeyword: Keyword? = nil,
        sourceActorID: String? = nil,
        applyStatBonus: Bool = true,
        applyItemBonus: Bool = true,
        applyDodge: Bool = true,
        in context: inout BattleEngineContext
    ) -> (healthLost: Int, damageEvents: [ActionEvent]) {
        var state = DamageResolutionState(
            amount: amount,
            combatant: combatant,
            sourceActorID: sourceActorID,
            damageKeyword: damageKeyword,
            applyStatBonus: applyStatBonus,
            applyItemBonus: applyItemBonus,
            applyDodge: applyDodge
        )

        DodgeGateStep().apply(to: &state, in: &context)
        if state.isDodged { return (0, state.damageEvents) }

        DamageBonusStep().apply(to: &state, in: &context)
        ShieldAbsorptionStep().apply(to: &state, in: &context)
        MitigationStep().apply(to: &state, in: &context)
        ItemReductionStep().apply(to: &state, in: &context)
        TakeDamageStep().apply(to: &state, in: &context)
        PreventionBuildupStep().apply(to: &state, in: &context)

        return (state.healthLost, state.damageEvents)
    }

    static func applyHeal(
        _ amount: Int,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) {
        let bonus = sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        context.roster.mutateRuntime(for: combatant) { $0.heal(amount + bonus) }
    }
}
