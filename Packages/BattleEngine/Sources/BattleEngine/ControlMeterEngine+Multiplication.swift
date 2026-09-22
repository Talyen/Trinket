import Foundation
import TrinketContent
import TrinketCore

package extension ControlMeterEngine {
    static func multiplyBuildup(
        _ factor: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
        abilityName: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard factor > 1,
              keyword == .freeze,
              context.roster.health(for: combatant) > 0,
              !context.roster.hasControlStatus(for: combatant, keyword: keyword)
        else {
            return []
        }

        var currentEffects = context.roster.activeEffects(for: combatant)
        guard let existingIndex = currentEffects.firstIndex(where: { activeEffect in
            guard case let .controlMeter(meterKeyword, _, _) = activeEffect.effect else { return false }
            return meterKeyword == keyword
        }),
            case let .controlMeter(_, currentAmount, threshold) = currentEffects[existingIndex].effect,
            currentAmount > 0,
            threshold > currentAmount
        else {
            return []
        }

        let newAmount = min(currentAmount * factor, threshold)
        guard newAmount > currentAmount else { return [] }

        let actorName = sourceActorID.flatMap { context.roster.combatant(for: $0)?.name } ?? combatant.name
        let amplificationEvent = context.nextEvent(
            kind: .effect,
            effectKind: .dotAmplified,
            actorName: actorName,
            abilityName: abilityName,
            target: combatant,
            amount: newAmount - currentAmount,
            keyword: keyword,
            origin: .direct,
        )

        if newAmount >= threshold {
            let thresholdEvents = applyThresholdReached(
                ControlMeterThresholdContext(
                    keyword: keyword,
                    combatant: combatant,
                    sourceActorID: sourceActorID,
                    existingIndex: existingIndex,
                    baseThreshold: threshold,
                    triggeredAmount: newAmount,
                ),
                currentEffects: &currentEffects,
                in: &context,
            )
            return [amplificationEvent] + thresholdEvents
        }

        updateBuildup(
            ControlMeterUpdate(
                keyword: keyword,
                newAmount: newAmount,
                threshold: threshold,
                combatant: combatant,
                sourceActorID: sourceActorID,
                existingIndex: existingIndex,
            ),
            currentEffects: &currentEffects,
            in: &context,
        )
        return [amplificationEvent]
    }
}
