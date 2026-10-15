import TrinketContent
import TrinketCore

/// Resolution scopes and synchronous entry points for isolated commands.
/// Internal reactions use async overloads within the enclosing executor.
package extension BattleState {
    /// Retaliation and talent pings share the same reaction damage policy.
    mutating func dealReactionDamage(
        _ amount: Int, to target: Combatant, keyword: Keyword, sourceActorID: String?,
    ) async -> CombatOutcome {
        await resolveDamage(DamageRequest(
            amount: amount, target: target, keyword: keyword, sourceActorID: sourceActorID,
            options: .reaction(),
        ))
    }

    mutating func withAutomaticPlay<Value>(_ body: (inout BattleState) throws -> Value) rethrows -> Value {
        resolution.beginAutomaticPlay()
        defer { resolution.endAutomaticPlay() }
        return try body(&self)
    }

    mutating func withAutomaticPlay<Value>(_ body: (inout BattleState) async throws -> Value) async rethrows -> Value {
        resolution.beginAutomaticPlay()
        defer { resolution.endAutomaticPlay() }
        return try await body(&self)
    }

    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityID: String = "",
        abilityName: String,
        isTheft: Bool = false,
        isDirectCardGain: Bool = false,
        isLeechOverflow: Bool = false,
    ) {
        _ = CombatExecutor.run { await grantGold(
            amount,
            to: combatant,
            abilityID: abilityID, abilityName: abilityName,
            isTheft: isTheft,
            isDirectCardGain: isDirectCardGain,
            isLeechOverflow: isLeechOverflow,
        ) }
    }

    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityID: String = "",
        abilityName: String,
        source: Combatant? = nil,
    ) {
        CombatExecutor
            .run { await restoreManaEmitting(amount, to: combatant, abilityID: abilityID, abilityName: abilityName, source: source) }
    }

    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityID: String = "",
        abilityName: String,
        keyword: Keyword = .health,
        isDirectCardHeal: Bool = false,
    ) {
        CombatExecutor.run { await healEmitting(
            amount: amount,
            target: target,
            source: source,
            abilityID: abilityID, abilityName: abilityName,
            keyword: keyword,
            isDirectCardHeal: isDirectCardHeal,
        ) }
    }

    mutating func appendDefeatMilestonesIfNeeded() {
        CombatExecutor.run { await appendDefeatMilestonesIfNeeded() }
    }

    mutating func resolveDamage(_ request: DamageRequest) -> CombatOutcome {
        CombatExecutor.run { await resolveDamage(request) }
    }

    mutating func resolveHeal(_ request: HealRequest) -> CombatOutcome {
        CombatExecutor.run { await resolveHeal(request) }
    }

    mutating func applyControlMeter(
        _ amount: Int,
        keyword: Keyword,
        to combatant: Combatant,
        sourceActorID: String?,
    ) {
        CombatExecutor.run { await applyControlMeter(amount, keyword: keyword, to: combatant, sourceActorID: sourceActorID) }
    }

    mutating func resolveDoTTick(
        basePotency: Int,
        keyword: Keyword,
        target: Combatant,
        sourceActorID: String?,
    ) -> CombatOutcome {
        CombatExecutor
            .run { await resolveDoTTick(basePotency: basePotency, keyword: keyword, target: target, sourceActorID: sourceActorID) }
    }

    mutating func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance? = nil,
    ) {
        CombatExecutor.run { await applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: effectTarget,
            sourceActorID: sourceActorID,
            application: application,
            provenance: provenance,
        ) }
    }
}
