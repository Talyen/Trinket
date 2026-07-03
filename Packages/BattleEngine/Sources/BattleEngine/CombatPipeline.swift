import Foundation
import TrinketCore
import TrinketContent

/// Damage resolution orchestration. Healing and prevention live in
/// `HealingEngine` and `PreventionEngine`.
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

        DamagePipeline.run(state: &state, in: &context)

        return CombatOutcome.fromDamage(state: state)
    }

    public static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        HealingEngine.resolveHeal(request, in: &context)
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
        PreventionEngine.applyBuildup(
            amount,
            keyword: keyword,
            to: combatant,
            sourceActorID: sourceActorID,
            in: &context
        )
    }

    public static func applyLeechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        HealingEngine.leechFromDamage(damage, sourceActorID: sourceActorID, in: &context).events
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
