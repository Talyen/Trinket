import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterAffixAllyHeal(_ request: HealRequest, in context: inout BattleState) {
        guard let sourceID = request.sourceActorID, sourceID != request.target.id,
              request.target.role != .enemy,
              let source = context.roster.combatant(for: sourceID), source.role != .enemy, source.isAlive else { return }
        let triggers = context.modifiers(for: sourceID).triggers
        if triggers.holyAttackBonusAfterAllyHeal > 0 {
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.turn.healedAlly = true }
        }
        if request.isDirectCardHeal, triggers.cardHealAllyThorns > 0 {
            heroTalentThorns(
                to: request.target, source: source.combatant, amount: triggers.cardHealAllyThorns,
                name: triggerAbilityName(.cardHealAllyThorns, for: source.combatant, fallback: "Thornstitch", in: context),
                in: &context,
            )
        }
    }

    static func afterRedTemperOverheal(_ overflow: Int, by actor: Combatant, in context: inout BattleState) -> Int {
        let cap = context.modifiers(for: actor.id).triggers.attackLeechOverflowBlockCap
        guard cap > 0, overflow > 0, context.roster.health(for: actor) > 0 else { return 0 }
        let amount = context.resolution.reserveRedTemperBlock(overflow, cap: cap, actorID: actor.id)
        guard amount > 0 else { return 0 }
        return context.applyBlockGain(
            amount, to: actor, source: actor,
            abilityName: triggerAbilityName(.attackLeechOverflowBlockCap, for: actor, fallback: "Red Temper", in: context),
            amountBasis: .resolved,
        )
    }

    internal static func afterAffixSupportCard(_ facts: ResolvedActionFacts, in context: inout BattleState) {
        let actor = facts.action.actor
        let amount = context.modifiers(for: actor.id).triggers.allySupportCardDodgePercent
        guard facts.targetsOnlyAlly, amount > 0 else { return }
        context.roster.mutateRuntime(for: actor) {
            $0.talents.turn.sideLacedDodgeBonus = max($0.talents.turn.sideLacedDodgeBonus, amount)
        }
    }

    static func afterAffixGoldTheft(by actor: Combatant, amount: Int, in context: inout BattleState) {
        guard amount > 0, let owner = context.roster.participant(for: actor), owner.isPartyMember else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        context.prepareAttackBonus(triggers.goldTheftNextHitBlockBypass, \.tolltakerBlockBypass, for: actor)
        let block = triggers.firstGoldTheftAllyBlock
        guard block > 0, context.resolution.claim(.affix(.smugglersLining), actorID: actor.id, cadence: .battle) else { return }
        let ally = owner == .hero ? context.roster.companion : context.roster.hero
        guard ally.isAlive else { return }
        emitBlock(.firstGoldTheftAllyBlock, "Smuggler's Lining", amount: block, to: ally.combatant, source: actor, in: &context)
    }

    static func reserveVerdigris(
        _ hit: DamageResolutionState,
        in context: inout BattleState,
    ) -> (wearer: Combatant, amount: Int)? {
        guard hit.options.isPrimaryAttack, hit.amount > 0, hit.combatant.role == .enemy, hit.targetStatus.isPoisoned,
              let source = hit.partySource(in: context), source.isAlive else { return nil }
        let wearer = source.role == .hero ? context.roster.companion : context.roster.hero
        let amount = context.modifiers(for: wearer.id).triggers.allyHitPoisonedExtraBlockRemoval
        guard wearer.isAlive, amount > 0,
              context.resolution.claim(.affix(.verdigris), actorID: wearer.id, cadence: .turn(context.turnCount)) else { return nil }
        return (wearer.combatant, amount)
    }

    static func applyVerdigris(
        wearer: Combatant, amount: Int, target: Combatant, in context: inout BattleState,
    ) {
        let before = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: target))
        let removed = min(before, amount)
        guard removed > 0 else { return }
        DefensePoolEngine.set(before - removed, on: target, in: &context)
        context.nextEvent(
            kind: .effect(.blockStripped), source: .init(wearer),
            abilityName: triggerAbilityName(.allyHitPoisonedExtraBlockRemoval, for: wearer, fallback: "Verdigris", in: context),
            target: target, amount: removed, keyword: .block,
        )
    }

    static func afterFinalBleedTick(sourceID: String?, in context: inout BattleState) async {
        guard let sourceID, let source = context.roster.combatant(for: sourceID),
              source.role != .enemy, source.isAlive else { return }
        let ally = source.role == .hero ? context.roster.companion : context.roster.hero
        let amount = context.modifiers(for: sourceID).triggers.finalBleedTickAllyHeal
        guard ally.isAlive, amount > 0 else { return }
        await emitHeal(.finalBleedTickAllyHeal, "Red Thread", amount: amount, to: ally.combatant, source: source.combatant, in: &context)
    }

    static func afterVigilBellSkip(effectID: Int, in context: inout BattleState) {
        guard let stun = context.resolution.vigilBellStun, stun.effectID == effectID,
              let source = context.roster.combatant(for: stun.sourceActorID), source.role != .enemy, source.isAlive,
              let sourceOwner = context.roster.participant(for: source.combatant) else { return }
        let ally: BattleParticipant = sourceOwner == .hero ? .companion : .hero
        guard context.roster[ally].isAlive else { return }
        let drawn = BattleCardCombatEngine.drawCards(count: 1, for: ally, context: &context)
        guard drawn > 0 else { return }
        context.nextEvent(
            kind: .effect(.cardsDrawn), source: .init(source.combatant),
            abilityName: triggerAbilityName(.stunSkipDrawsAllyCard, for: source.combatant, fallback: "Vigil Bell", in: context),
            target: context.roster[ally].combatant, amount: drawn, keyword: .stun,
        )
    }

    static func afterAffixStun(sourceActorID: String?, in context: inout BattleState) async {
        guard let sourceActorID, let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy, source.isAlive, context.roster.enemy.isAlive else { return }
        let actor = source.combatant
        let triggers = context.modifiers(for: sourceActorID).triggers
        let hadNoBlock = DefensePoolEngine.blockPoints(in: source.activeEffects) == 0
        let hadNoMana = source.currentMana == 0 && source.maxMana > 0
        if hadNoBlock, triggers.stunBlockIfNone > 0 {
            emitBlock(.stunBlockIfNone, "Steadfast", amount: triggers.stunBlockIfNone, to: actor, source: actor, in: &context)
        }
        if hadNoMana, triggers.stunManaIfNone > 0, context.health(of: actor) > 0 {
            await emitMana(.stunManaIfNone, "Arcane", amount: triggers.stunManaIfNone, to: actor, in: &context)
        }
    }

    static func afterAffixFreeze(sourceActorID: String?, in context: inout BattleState) async {
        guard let sourceActorID, let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy, source.isAlive else { return }
        let amount = context.modifiers(for: sourceActorID).triggers.freezeDealPhysicalFlat
        guard amount > 0 else { return }
        await heroTalentDamage(
            .physical, amount: amount, source: source.combatant,
            name: triggerAbilityName(.freezeDealPhysicalFlat, for: source.combatant, fallback: "Shattering", in: context),
            in: &context,
        )
    }

    static func afterAffixBlockBreak(on actor: Combatant, attackerID: String?, in context: inout BattleState) async {
        guard actor.role != .enemy, context.health(of: actor) > 0 else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        if triggers.blockBrokenHealFlat > 0 {
            await emitHeal(.blockBrokenHealFlat, "Resolute", amount: triggers.blockBrokenHealFlat, to: actor, source: actor, in: &context)
        }
        guard context.health(of: actor) > 0, triggers.blockBrokenStunFlat > 0,
              let attackerID, attackerID == context.roster.enemy.id, context.roster.enemy.isAlive else { return }
        await heroTalentDamage(
            .stun, amount: triggers.blockBrokenStunFlat, source: actor,
            name: triggerAbilityName(.blockBrokenStunFlat, for: actor, fallback: "Reactive", in: context),
            in: &context,
        )
    }

    static func afterAffixAttack(_ state: CommittedDamage, in context: inout BattleState) async {
        guard state.options.isPrimaryAttack, state.healthLost > 0,
              state.combatant.role == .enemy,
              let source = state.partySource(in: context), source.isAlive else { return }
        await kinboundHeal(damage: state.healthLost, attacker: source.combatant, in: &context)
        guard context.health(of: source.combatant) > 0, context.roster.enemy.isAlive,
              state.options.isCardAttack, state.damageKeyword == .physical else { return }
        let chance = context.modifiers(for: source.id).triggers.physicalAttackBleedChancePercent
        guard chance > 0,
              let card = context.resolution.cardTalents, card.actorID == source.id,
              context.resolution.claim(.affix(.bloodletting), actorID: source.id, cadence: .card(card.playSerial)),
              BattleChance.succeeds(probability: min(1, chance), using: &context.rng) else { return }
        await heroTalentDamage(
            .bleed, amount: 1, source: source.combatant,
            name: triggerAbilityName(.physicalAttackBleedChancePercent, for: source.combatant, fallback: "Bloodletting", in: context),
            in: &context,
        )
    }

    private static func kinboundHeal(damage: Int, attacker: Combatant, in context: inout BattleState) async {
        let wearer = attacker.id == context.roster.hero.id ? context.roster.companion.combatant : context.roster.hero.combatant
        let percent = context.modifiers(for: wearer.id).triggers.allyAttackHealBelowHalfPercent
        guard percent > 0, context.health(of: wearer) > 0, context.roster.isBelowHalfHealth(for: wearer) else { return }
        let amount = CombatRounding.scaled(damage, multiplier: percent)
        guard amount > 0 else { return }
        await emitHeal(.allyAttackHealBelowHalfPercent, "Kinbound", amount: amount, to: wearer, source: wearer, in: &context)
    }
}
