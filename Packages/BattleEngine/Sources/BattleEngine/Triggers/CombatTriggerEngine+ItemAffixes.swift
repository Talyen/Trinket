import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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

    static func afterAffixAttack(_ state: DamageResolutionState, in context: inout BattleState) async {
        guard state.options.isAttackHit, !state.options.isRetaliation, state.healthLost > 0,
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
