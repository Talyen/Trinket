import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleState {
    @discardableResult
    mutating func chargeTestControl(
        _ amount: Int,
        keyword: Keyword,
        to target: Combatant,
        sourceActorID: String?,
        applyFightPacing: Bool = true,
    ) -> [ActionEvent] {
        recordingEvents { context in
            await ControlMeterEngine.applyMeterCharge(
                amount, keyword: keyword, to: target, sourceActorID: sourceActorID,
                applyFightPacing: applyFightPacing, in: &context,
            )
        }
    }

    /// Resolves one engine action without moving a physical hand card.
    @discardableResult
    mutating func performTestAction(
        _ ability: Ability,
        from source: BattleParticipant = .hero,
        to target: BattleParticipant = .enemy,
    ) -> [ActionEvent] {
        recordingEvents { context in
            await BattleTurnEngine.performAction(
                ability: ability, actor: context.roster[source].combatant, abilityTarget: context.roster[target].combatant,
                context: &context,
            )
        }
    }

    @discardableResult
    mutating func resolveTestDamage(
        _ amount: Int,
        from source: BattleParticipant = .hero,
        to target: BattleParticipant = .enemy,
        keyword: Keyword = .physical,
        options: DamageOperation = .attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
    ) -> CombatOutcome {
        resolveDamage(DamageRequest(
            amount: amount, target: roster[target].combatant, keyword: keyword,
            sourceActorID: roster[source].id, options: options,
        ))
    }

    @discardableResult
    mutating func resolveTestDamage(
        _ amount: Int,
        to target: Combatant,
        keyword: Keyword? = nil,
        sourceActorID: String? = nil,
        options: DamageOperation = .attack(),
    ) -> CombatOutcome {
        resolveDamage(DamageRequest(
            amount: amount, target: target, keyword: keyword,
            sourceActorID: sourceActorID, options: options,
        ))
    }
}

extension BattleState {
    mutating func recordingResult<Value>(
        _ operation: (inout BattleState) async -> Value,
    ) -> (events: [ActionEvent], value: Value) {
        let result = CombatExecutor.run { await collectingResult(operation) }
        return (result.events, result.value)
    }

    mutating func recordingEvents(_ operation: (inout BattleState) async -> Void) -> [ActionEvent] {
        CombatExecutor.run { await collectingEvents(operation) }
    }

    mutating func recordingEvents(_ operation: (inout BattleState) async throws -> Void) throws -> [ActionEvent] {
        try CombatExecutor.run { try await collectingEvents(operation) }
    }
}
