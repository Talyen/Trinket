import Foundation
import TrinketContent
import TrinketCore

package enum DoTDamage {
    public static func resolveTurnDamage(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard basePotency > 0 else { return .empty }

        let damageOutcome = context.resolveDamage(
            .doTTick(
                amount: basePotency,
                target: target,
                keyword: keyword,
                sourceActorID: sourceActorID
            )
        )
        guard damageOutcome.healthLost > 0 else { return damageOutcome }

        let statusEvent = context.nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: damageOutcome.healthLost,
            keyword: keyword
        )
        return CombatOutcome(
            healthDelta: damageOutcome.healthDelta,
            events: damageOutcome.events + [statusEvent],
            flags: damageOutcome.flags
        )
    }
}
