import Foundation
import TrinketCore
import TrinketContent

/// Stun/freeze prevention buildup and threshold transitions.
package enum PreventionEngine {
    public static func applyBuildup(
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
            return applyThresholdReached(
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

        updateBuildup(
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

    private static func applyThresholdReached(
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

    private static func updateBuildup(
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
}
