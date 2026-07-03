import Foundation
import TrinketCore
import TrinketContent

/// DoT tick damage: resolves base potency through the damage pipeline (stat
/// and item bonuses at tick time) and appends the `.status` log line.
public enum DoTDamage {
    public static func resolveTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard basePotency > 0 else { return .empty }

        let damageOutcome = CombatPipeline.resolveDamage(
            .doTTick(
                amount: basePotency,
                target: target,
                keyword: keyword,
                sourceActorID: sourceActorID
            ),
            in: &context
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
