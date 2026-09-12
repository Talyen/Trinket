import Foundation
import TrinketContent
import TrinketCore

package enum DoTDamage {
    public static func resolveDamage(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        guaranteedCritical: Bool = false,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard basePotency > 0 else { return .empty }

        var request = DamageRequest.doTTick(
            amount: basePotency,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
        )
        request.options.guaranteedCritical = guaranteedCritical
        request.provenance = provenance
        let damageOutcome = context.resolveDamage(request)
        guard damageOutcome.healthLost > 0 else { return damageOutcome }

        let statusEvent = context.nextEvent(
            kind: .status,
            effectKind: nil,
            actorName: keyword.rawValue,
            abilityName: keyword.rawValue,
            target: target,
            amount: damageOutcome.healthLost,
            keyword: keyword,
            isCritical: damageOutcome.isCritical,
        )
        return CombatOutcome(
            healthDelta: damageOutcome.healthDelta,
            events: damageOutcome.events + [statusEvent],
            flags: damageOutcome.flags,
        )
    }
}
