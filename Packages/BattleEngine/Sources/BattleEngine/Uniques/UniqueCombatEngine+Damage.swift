import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func prepareDamage(_ request: DamageRequest, in context: inout BattleState) -> DamageRequest {
        guard !request.options.isHealthCost, let sourceID = request.sourceActorID,
              isOrdinaryAction(actorID: sourceID, in: context) else { return request }
        var prepared = request
        if context.uniques.card?.guaranteedCritical == true {
            prepared.options.guaranteedCritical = true
        }
        prepared.options.capturesCardRepeat = context.uniques.card?.repeatDamage == true
        if request.target.role == .enemy, request.amount > 0 {
            prepared.options.partnerFirstAttackBonus = context.uniques.card?.attackBonus ?? 0
            context.uniques.card?.attackBonus = 0
        }
        return prepared
    }

    static func captureCardDamage(
        _ damage: DamageResolutionState,
        outgoingAmount: Int,
        in context: inout BattleState,
    ) {
        guard context.uniques.card?.repeatDamage == true,
              damage.options.capturesCardRepeat, !damage.options.isResolvedCardRepeat,
              let sourceID = damage.sourceActorID,
              isOrdinaryAction(actorID: sourceID, in: context) else { return }
        var options = damage.options.repeated(scaling: .resolved, guaranteedCritical: damage.isCritical)
        options.capturesCardRepeat = true
        let request = DamageRequest(
            amount: outgoingAmount,
            target: damage.combatant,
            keyword: damage.damageKeyword,
            sourceActorID: sourceID,
            options: options,
        )
        context.uniques.card?.damageRequests.append(.init(request: request, stackPotency: damage.amount))
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
        damage.unique.enemyBlock = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: damage.combatant))
    }

    static func applyStoredDamage(to damage: inout DamageResolutionState, in context: inout BattleState) {
        damage.remaining += damage.unique.enemyBlock
        damage.remaining += damage.options.partnerFirstAttackBonus
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
