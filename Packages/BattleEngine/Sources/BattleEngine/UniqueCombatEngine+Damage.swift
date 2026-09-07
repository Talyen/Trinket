import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func prepareDamage(_ request: DamageRequest, in context: inout BattleState) -> DamageRequest {
        guard !request.options.isHealthCost, let sourceID = request.sourceActorID,
              isOrdinaryAction(actorID: sourceID, in: context) else { return request }
        var prepared = request
        prepared.amount += context.uniques.card?.attackBonus ?? 0
        context.uniques.card?.attackBonus = 0
        prepared.options.isOrdinaryUniqueCardDamage = true
        if context.uniques.card?.guaranteedCritical == true {
            prepared.options.guaranteedCritical = true
        }
        context.uniques.card?.damageRequests.append(prepared)
        return prepared
    }

    static func sharedDamageKeyword(for keyword: Keyword, triggers: CombatTraitTriggers) -> Keyword? {
        switch keyword {
        case .holy where triggers.physicalBonusesApplyToHoly: .physical
        case .burn where triggers.burnAndBleedShareDamageBonuses: .bleed
        case .bleed where triggers.burnAndBleedShareDamageBonuses: .burn
        default: nil
        }
    }

    static func captureEnemyBlock(for damage: inout DamageResolutionState, in context: BattleState) {
        guard damage.combatant.role == .enemy, damage.damageKeyword == .stun,
              let sourceID = damage.sourceActorID,
              context.modifiers(for: sourceID).triggers.stunDamageAddsEnemyBlock
        else { return }
        damage.uniqueEnemyBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: damage.combatant))
    }

    static func applyStoredDamage(to damage: inout DamageResolutionState, in context: inout BattleState) {
        damage.remaining += damage.uniqueEnemyBlock
        guard damage.options.isOrdinaryUniqueCardDamage, damage.damageKeyword == .holy,
              let source = damage.partySource(in: context),
              let owner = context.roster.participant(for: source.combatant)
        else { return }
        damage.remaining += context.uniques.owners[owner]?.goldDamage ?? 0
        context.uniques.owners[owner, default: .init()].goldDamage = 0
    }

    static func ignoresBlock(for damage: DamageResolutionState, in context: BattleState) -> Bool {
        guard damage.combatant.role == .enemy, let sourceID = damage.sourceActorID else { return false }
        let triggers = context.modifiers(for: sourceID).triggers
        if damage.damageKeyword == .stun, triggers.stunDamageAddsEnemyBlock {
            return true
        }
        return damage.options.isAttackHit && triggers.attacksIgnoreBlockWhileTargetPoisoned && damage.targetStatus.isPoisoned
    }

    static func gainedGold(_ amount: Int, by actor: Combatant, in context: inout BattleState) {
        guard amount > 0, context.modifiers(for: actor.id).triggers.goldGainedNextHolyDamage,
              let owner = context.roster.participant(for: actor), owner.isPartyMember
        else { return }
        context.uniques.owners[owner, default: .init()].goldDamage += amount
    }
}
