import Foundation
import TrinketContent
import TrinketCore

/// Stun/freeze control meter: tracks charge toward the next action skip.
package enum ControlMeterEngine {
    public static func applyMeterCharge(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard amount > 0, context.roster.health(for: combatant) > 0 else { return [] }
        if context.roster.hasPendingActionSkip(for: combatant, keyword: keyword) { return [] }

        let profile = context.modifiers(for: combatant.id)
        var adjustedAmount = amount
        if profile.controlResistancePercent > 0 {
            adjustedAmount = Int(floor(Double(adjustedAmount) * (1 - min(1, profile.controlResistancePercent))))
        }
        if keyword == .freeze, profile.freezeControlVulnerabilityPercent > 0 {
            adjustedAmount = Int(ceil(Double(adjustedAmount) * (1 + profile.freezeControlVulnerabilityPercent)))
        }
        guard adjustedAmount > 0 else { return [] }

        let threshold = controlMeterThreshold(for: combatant, in: context)
        var currentEffects = context.roster.activeEffects(for: combatant)
        let existingIndex = currentEffects.firstIndex { activeEffect in
            if case let .controlMeter(k, _, _) = activeEffect.effect, k == keyword { return true }
            return false
        }
        let existingAmount = existingMeterAmount(at: existingIndex, in: currentEffects)
        let newAmount = min(existingAmount + adjustedAmount, threshold)

        if newAmount >= threshold {
            return applyThresholdReached(
                ControlMeterThresholdContext(
                    keyword: keyword,
                    combatant: combatant,
                    sourceActorID: sourceActorID,
                    existingIndex: existingIndex,
                    threshold: threshold
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

    private static func controlMeterThreshold(for combatant: Combatant, in context: BattleEngineContext) -> Int {
        combatant.primaryStats.controlMeterThreshold(
            baseMaxHealth: context.roster.maxHealth(for: combatant)
        )
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

    private static func applyThresholdReached(
        _ thresholdContext: ControlMeterThresholdContext,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleEngineContext
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
                effectKind: .controlTriggered,
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
        in context: inout BattleEngineContext
    ) {
        let buildup = Effect.controlMeter(update.keyword, update.newAmount, update.threshold)
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
                    id: context.consumeNextEffectID(),
                    effect: buildup,
                    remainingTicks: 0,
                    sourceActorID: update.sourceActorID
                )
            )
        }
        context.roster.setActiveEffects(currentEffects, for: update.combatant)
    }
}
