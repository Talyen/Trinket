import Foundation
import TrinketContent
import TrinketCore

/// Stun/freeze control meter: tracks charge toward the next action skip.
package enum ControlMeterEngine {
    /// - Parameter applyFightPacing: When `true` (default), scales `amount` via fight pacing.
    ///   Damage-pipeline callers pass `false` because `buildupDamage` is already paced.
    public static func applyMeterCharge( // swiftlint:disable:this function_body_length
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        applyFightPacing: Bool = true,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return [] }
        // Block further charge while Stunned/Frozen, including post-skip linger.
        if context.roster.hasControlStatus(for: combatant, keyword: keyword) {
            return []
        }
        let pacedAmount = applyFightPacing
            ? (sourceActorID.map { context.paced(amount, sourceActorID: $0) } ?? amount)
            : amount
        guard pacedAmount > 0 else { return [] }

        let profile = context.modifiers(for: combatant.id)
        var adjustedAmount = pacedAmount
        if profile.triggers.controlResistancePercent > 0 {
            adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: 1 - min(1, profile.triggers.controlResistancePercent))
        }
        if keyword == .freeze, profile.triggers.freezeControlVulnerabilityPercent > 0 {
            adjustedAmount = CombatRounding.scaled(
                adjustedAmount,
                multiplier: 1 + profile.triggers.freezeControlVulnerabilityPercent
            )
        }
        // Steadfast / Lichbone: control-buildup resistance.
        if keyword == .stun || keyword == .freeze {
            let targetTriggers = context.modifiers(for: combatant.id).triggers
            let steadfastResistance = targetTriggers.blockedControlBurnResistance > 0
                && DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: combatant)) > 0
                ? targetTriggers.blockedControlBurnResistance
                : 0
            let lichboneResistance = keyword == .stun ? targetTriggers.afflictionResistance : 0
            let controlResistance = max(steadfastResistance, lichboneResistance)
            if controlResistance > 0 {
                adjustedAmount = CombatRounding.scaled(adjustedAmount, multiplier: 1 - min(1, controlResistance))
            }
        }
        guard adjustedAmount > 0 else { return [] }

        let threshold = threshold(for: combatant, in: context)
        // Seismic Impact: enemies require less Stun buildup to become Stunned.
        let effectiveThreshold: Int = if keyword == .stun, combatant.role == .enemy, let sourceActorID,
                                         context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent > 0 {
            CombatRounding.scaled(
                threshold,
                multiplier: 1 - min(1, context.modifiers(for: sourceActorID).triggers.enemyStunThresholdReductionPercent)
            )
        } else {
            threshold
        }
        var currentEffects = context.roster.activeEffects(for: combatant)
        let existingIndex = currentEffects.firstIndex { activeEffect in
            if case let .controlMeter(k, _, _) = activeEffect.effect, k == keyword {
                return true
            }
            return false
        }
        let existingAmount = existingMeterAmount(at: existingIndex, in: currentEffects)
        guard existingAmount < effectiveThreshold else { return [] }
        let newAmount = min(existingAmount + adjustedAmount, effectiveThreshold)

        if newAmount >= effectiveThreshold {
            return applyThresholdReached(
                ControlMeterThresholdContext(
                    keyword: keyword,
                    combatant: combatant,
                    sourceActorID: sourceActorID,
                    existingIndex: existingIndex,
                    threshold: effectiveThreshold
                ),
                currentEffects: &currentEffects,
                in: &context
            )
        }

        updateBuildup(
            ControlMeterUpdate(
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

    public static func threshold(for combatant: Combatant, in context: BattleState) -> Int {
        combatant.primaryStats.controlMeterThreshold(
            baseMaxHealth: context.roster.maxHealth(for: combatant)
        )
    }

    /// End-of-round Freeze-buildup decay (25% of current buildup, floor). Skipped when the
    /// buildup's source carries `freezeBuildupDoesNotDecay` (Persistent Frost / Glacial Grip).
    /// Full meters (Frozen status) are left intact for the control-lock handler.
    package static func decayFreezeBuildup(
        on combatant: Combatant,
        in context: inout BattleState
    ) {
        var effects = context.roster.activeEffects(for: combatant)
        var changed = false
        for index in effects.indices {
            guard case let .controlMeter(kw, amount, threshold) = effects[index].effect,
                  kw == .freeze,
                  amount > 0,
                  amount < threshold
            else { continue }
            if let sourceID = effects[index].sourceActorID,
               context.modifiers(for: sourceID).triggers.freezeBuildupDoesNotDecay {
                continue
            }
            let decayed = max(0, amount - amount * 25 / 100)
            if decayed != amount {
                effects[index] = ActiveEffect(
                    id: effects[index].id,
                    effect: .controlMeter(.freeze, decayed, threshold),
                    remainingTurns: effects[index].remainingTurns,
                    sourceActorID: effects[index].sourceActorID
                )
                changed = true
            }
        }
        if changed {
            context.roster.setActiveEffects(effects, for: combatant)
        }
    }

    private static func existingMeterAmount(
        at existingIndex: Int?,
        in currentEffects: [ActiveEffect]
    ) -> Int {
        guard let existingIndex,
              case let .controlMeter(_, amount, _) = currentEffects[existingIndex].effect
        else { return 0 }
        return amount
    }

    private struct ControlMeterThresholdContext {
        let keyword: Keyword
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
        let threshold: Int
    }

    // swiftlint:disable:next function_body_length
    private static func applyThresholdReached(
        _ thresholdContext: ControlMeterThresholdContext,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState
    ) -> [ActionEvent] {
        let keyword = thresholdContext.keyword
        let combatant = thresholdContext.combatant
        let sourceActorID = thresholdContext.sourceActorID
        let threshold = thresholdContext.threshold

        updateBuildup(
            ControlMeterUpdate(
                keyword: keyword,
                newAmount: threshold,
                threshold: threshold,
                combatant: combatant,
                sourceActorID: sourceActorID,
                existingIndex: thresholdContext.existingIndex
            ),
            currentEffects: &currentEffects,
            in: &context
        )
        if keyword == .freeze,
           let sourceActorID,
           context.modifiers(for: sourceActorID).triggers.freezeExtraActionSkips > 0 {
            context.additionalControlSkipsByCombatantID[combatant.id, default: 0] +=
                context.modifiers(for: sourceActorID).triggers.freezeExtraActionSkips
        }
        if keyword == .stun,
           let sourceActorID,
           context.modifiers(for: sourceActorID).triggers.enemyStunExtraActionSkips > 0 {
            let extra = min(1, context.modifiers(for: sourceActorID).triggers.enemyStunExtraActionSkips)
            let current = context.additionalControlSkipsByCombatantID[combatant.id, default: 0]
            context.additionalControlSkipsByCombatantID[combatant.id] = min(1, current + extra)
        }

        let actorName: String = if let sourceActorID, let source = context.roster.combatant(for: sourceActorID) {
            source.name
        } else {
            combatant.name
        }
        let abilityName = keyword.statusAlias ?? keyword.rawValue
        var events = [
            context.nextEvent(
                kind: .effect,
                effectKind: .controlTriggered,
                actorName: actorName,
                abilityName: abilityName,
                target: combatant,
                amount: 0,
                keyword: keyword,
                appliedEffectSummaries: [],
                milestone: nil
            ),
        ]
        if keyword == .stun, combatant.id == context.roster.enemy.id {
            events.append(contentsOf: CombatTriggerEngine.afterEnemyStunned(in: &context))
        }
        // Glacial Barrier: gain Block whenever the enemy becomes Frozen.
        if keyword == .freeze,
           combatant.role == .enemy,
           let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID),
           context.modifiers(for: sourceActorID).triggers.onEnemyFrozenGainBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                context.modifiers(for: sourceActorID).triggers.onEnemyFrozenGainBlock,
                to: source.combatant,
                source: source.combatant,
                abilityName: "Glacial Barrier"
            ))
        }
        // Volcanic Stun: Stunning the enemy also inflicts Burn.
        if keyword == .stun,
           combatant.role == .enemy,
           let sourceActorID,
           context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn > 0,
           context.roster.health(for: combatant) > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .burn,
                potency: context.modifiers(for: sourceActorID).triggers.onStunEnemyApplyBurn,
                to: combatant,
                sourceActorID: sourceActorID,
                dealImmediateDamage: false,
                suppressAffixReactions: true
            ))
        }
        return events
    }

    private struct ControlMeterUpdate {
        let keyword: Keyword
        let newAmount: Int
        let threshold: Int
        let combatant: Combatant
        let sourceActorID: String?
        let existingIndex: Int?
    }

    private static func updateBuildup(
        _ update: ControlMeterUpdate,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState
    ) {
        let buildup = Effect.controlMeter(update.keyword, update.newAmount, update.threshold)
        if let existingIndex = update.existingIndex {
            currentEffects[existingIndex] = ActiveEffect(
                id: currentEffects[existingIndex].id,
                effect: buildup,
                remainingTurns: currentEffects[existingIndex].remainingTurns,
                sourceActorID: currentEffects[existingIndex].sourceActorID
            )
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: buildup,
                    remainingTurns: 0,
                    sourceActorID: update.sourceActorID
                )
            )
        }
        context.roster.setActiveEffects(currentEffects, for: update.combatant)
    }
}
