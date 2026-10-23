import TrinketContent
import TrinketCore

/// Hit facts frozen after defense and Health commitment. Reactions mutate the
/// live battle in order; they cannot modify outgoing calculations or this hit.
package struct CommittedDamage {
    let amount: Int
    let combatant: Combatant
    let sourceActorID: String?
    let damageKeyword: Keyword?
    let options: DamageOperation
    let provenance: DamageProvenance?
    let remaining: Int
    let healthLost: Int
    let blockedAmount: Int
    let isCritical: Bool
    let isDodged: Bool
    let targetWasStunnedAtHit: Bool
    let sourceHadNoBlockAtHit: Bool
    let talentAttackHasLeech: Bool
    let additionalHolyDamage: Int
    let additionalPhysicalDamage: Int
    let outgoingDamage: Int
    let blockAbsorbingOwners: [Combatant]
    let brokenBlockOwners: [Combatant]
    let heroCardBlockBroken: Bool

    init(_ state: DamageResolutionState) {
        amount = state.amount
        combatant = state.combatant
        sourceActorID = state.sourceActorID
        damageKeyword = state.damageKeyword
        options = state.options
        provenance = state.provenance
        remaining = state.remaining
        healthLost = state.healthLost
        blockedAmount = state.blockedAmount
        isCritical = state.isCritical
        isDodged = state.isDodged
        targetWasStunnedAtHit = state.targetStatus.isStunned
        sourceHadNoBlockAtHit = state.sourceHadNoBlockAtHit
        talentAttackHasLeech = state.talentAttackHasLeech
        additionalHolyDamage = state.additionalHolyDamage
        additionalPhysicalDamage = state.additionalPhysicalDamage
        outgoingDamage = state.unique.outgoingDamage
        blockAbsorbingOwners = state.blockAbsorbingOwners
        brokenBlockOwners = state.brokenBlockOwners
        heroCardBlockBroken = state.heroCardBlockBroken
    }

    func partySource(in context: BattleState) -> CombatantRuntime? {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy else { return nil }
        return source
    }

    /// Fractional grants qualify for riders without selecting ability-strength restoration.
    func hasGuaranteedAttackLeech(in context: BattleState) -> Bool {
        guard options.isAttackHit else { return false }
        return options.abilityHasLeech || talentAttackHasLeech
            || sourceActorID.map { context.modifiers(for: $0).triggers.attackLeechPercent > 0 } == true
    }
}
