import TrinketContent
import TrinketCore

/// Synchronous entry points for isolated engine commands. Internal reactions use
/// their async overloads so a child stays in the enclosing command executor.
package extension BattleState {
    mutating func withAutomaticPlay(_ body: (inout BattleState) throws -> [ActionEvent]) rethrows -> [ActionEvent] {
        resolution.beginAutomaticPlay()
        defer { resolution.endAutomaticPlay() }
        return try body(&self)
    }

    mutating func grantGoldEvent(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        isTheft: Bool = false,
        isDirectCardGain: Bool = false,
        isLeechOverflow: Bool = false,
    ) -> [ActionEvent] {
        CombatExecutor.run { await grantGoldEvent(
            amount,
            to: combatant,
            abilityName: abilityName,
            isTheft: isTheft,
            isDirectCardGain: isDirectCardGain,
            isLeechOverflow: isLeechOverflow,
        ) }
    }

    mutating func restoreManaEmitting(
        _ amount: Int,
        to combatant: Combatant,
        abilityName: String,
        actorName: String? = nil,
    ) -> [ActionEvent] {
        CombatExecutor.run { await restoreManaEmitting(amount, to: combatant, abilityName: abilityName, actorName: actorName) }
    }

    mutating func healEmitting(
        amount: Int,
        target: Combatant,
        source: Combatant,
        abilityName: String,
        keyword: Keyword = .health,
        isDirectCardHeal: Bool = false,
    ) -> [ActionEvent] {
        CombatExecutor.run { await healEmitting(
            amount: amount,
            target: target,
            source: source,
            abilityName: abilityName,
            keyword: keyword,
            isDirectCardHeal: isDirectCardHeal,
        ) }
    }

    mutating func appendDefeatMilestonesIfNeeded() -> [ActionEvent] {
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
    ) -> [ActionEvent] {
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
    ) -> [ActionEvent] {
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
