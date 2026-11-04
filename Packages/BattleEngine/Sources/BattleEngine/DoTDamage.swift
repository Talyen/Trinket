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
        operation: DamageOperation = .periodic,
        isDetonation: Bool = false,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard basePotency > 0 else { return .empty }

        var request = DamageRequest(
            amount: basePotency,
            target: target,
            keyword: keyword,
            sourceActorID: sourceActorID,
            options: operation,
        )
        request.options.guaranteedCritical = guaranteedCritical
        request.provenance = provenance
        let damageOutcome = await context.resolveDamage(request)
        guard damageOutcome.healthLost > 0 else { return damageOutcome }

        let reaction = isDetonation ? context.resolution.reactionPayoff : nil
        if reaction != nil {
            context.resolution.reactionHealthLost = SaturatedArithmetic.saturatingAdd(
                context.resolution.reactionHealthLost, damageOutcome.healthLost,
            )
        }
        context.nextEvent(
            kind: reaction == nil ? .status : .abilityDamage,
            source: .init(actorID: sourceActorID, name: keyword.rawValue),
            abilityName: reaction?.displayName ?? keyword.rawValue,
            target: target,
            amount: damageOutcome.healthLost,
            keyword: keyword,
            isCritical: damageOutcome.isCritical,
            reactionPayoff: reaction,
            isDetonation: isDetonation,
        )
        return damageOutcome
    }
}
