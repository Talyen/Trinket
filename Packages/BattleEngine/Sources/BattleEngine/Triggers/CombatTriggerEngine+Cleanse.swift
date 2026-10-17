import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func preventsDebuff(_ effect: Effect, on target: Combatant, in context: BattleState) -> Bool {
        guard effect.isRemovableDebuff else { return false }
        if context.roster.runtime(for: target)?.talents.turn.negativeStatusImmune == true {
            return true
        }
        if context.roster.runtime(for: target)?.talents.turn.cleansedKeywordProtection.contains(effect.keyword) == true {
            return true
        }
        return context.modifiers(for: target.id).triggers.deathsDoorNegativeStatusImmune
            && context.roster.isDeathsDoorActive(for: target)
    }

    static func performRandomCleanses(
        source: Combatant,
        target: Combatant,
        count: Int,
        abilityName: String,
        in context: inout BattleState,
    ) async {
        guard count > 0, context.roster.health(for: target) > 0 else { return }

        for _ in 0 ..< count {
            guard context.roster.health(for: source) > 0, context.roster.health(for: target) > 0 else { break }
            let outcome = await EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: source, target: target, abilityName: abilityName, in: &context,
            )

            if outcome.removed.isEmpty {
                break
            }
        }
    }

    static func afterCleanseAction(
        source: Combatant,
        target: Combatant,
        removedCount: Int,
        allowMassCleanse: Bool = true,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: source) > 0 else { return }
        let triggers = context.modifiers(for: source.id).triggers

        if removedCount > 0 {
            if triggers.cleanseNextAttackCriticalBonus > 0 {
                let preparedCardSerial = context.resolution.cardTalents?.playSerial
                let actionID = context.resolution.actionID
                context.roster.mutateRuntime(for: target) {
                    $0.talents.pending.nextCleanseCriticalBonus = PreparedTalentBonus(
                        value: max($0.talents.pending.nextCleanseCriticalBonus?.value ?? 0, triggers.cleanseNextAttackCriticalBonus),
                        cardSerial: preparedCardSerial,
                        actionID: actionID,
                    )
                }
            }
            if triggers.cleanseSelfBlockFlat > 0 {
                context.applyBlockGain(
                    SaturatedArithmetic.saturatingMul(triggers.cleanseSelfBlockFlat, removedCount),
                    to: source, source: source,
                    abilityName: triggerAbilityName(.cleanseSelfBlockFlat, for: source, fallback: "Clearheaded", in: context),
                )
            }
            if triggers.onCleanseRestoreMana > 0 {
                await emitMana(
                    .onCleanseRestoreMana, "Solace",
                    amount: SaturatedArithmetic.saturatingMul(triggers.onCleanseRestoreMana, removedCount),
                    to: source, in: &context,
                )
            }
            guard context.roster.health(for: source) > 0 else { return }
            cleanseShieldBonuses(
                triggers: triggers,
                source: source,
                target: target,
                removedCount: removedCount,
                allowPartyBlock: allowMassCleanse,
                in: &context,
            )
        }
        if allowMassCleanse {
            await dispelMagicPurge(triggers: triggers, source: source, in: &context)
            guard context.roster.health(for: source) > 0 else { return }
            if triggers.cleanseDodgeChanceBonus > 0 {
                EffectRemovalOperation.grantSecondaryCleanseDodge(source: source, target: target, in: &context)
            }
            await cleanseOtherPartyMember(source: source, target: target, in: &context)
        }
        guard context.roster.health(for: source) > 0 else { return }
        if source.role != .enemy, Self.hasLivingPartyTrigger(\.purifyingWaters, in: context), removedCount > 0 {
            let healTarget = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
            await context.healEmitting(
                amount: SaturatedArithmetic.saturatingMul(4, removedCount),
                target: healTarget,
                source: source,
                abilityName: "Purifying Waters",
            )
        }
    }

    private static func cleanseShieldBonuses(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        removedCount: Int,
        allowPartyBlock: Bool,
        in context: inout BattleState,
    ) {
        guard removedCount > 0 else { return }

        if triggers.cleanseBlockPerStack > 0 {
            emitBlock(
                .cleanseBlockPerStack, "Spellbreak Shield",
                amount: SaturatedArithmetic.saturatingMul(triggers.cleanseBlockPerStack, removedCount),
                to: target, source: source, in: &context,
            )
        }
        if triggers.cleanseTargetBlockFlat > 0 {
            context.applyBlockGain(triggers.cleanseTargetBlockFlat, to: target, source: source, abilityName: "Cleansing Ward")
        }
        guard allowPartyBlock, triggers.cleansePartyBlock > 0 else { return }
        for (_, member) in livingPartyMembers(in: context) {
            emitBlock(
                .cleansePartyBlock, "Cleansing Ward",
                amount: triggers.cleansePartyBlock, to: member.combatant, source: source, in: &context,
            )
        }
    }

    private static func dispelMagicPurge(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.enemy.isAlive else { return }
        var count = triggers.cleanseAlsoPurgesEnemyBuffs
        if count == 0, triggers.cleansePurgeChancePercent > 0,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: \.effect.isRemovableBuff),
           context.claimTalentAbility(.dispelMagic, actorID: source.id),
           BattleChance.succeeds(probability: triggers.cleansePurgeChancePercent, using: &context.rng) {
            count = 1
        }
        guard count > 0 else { return }
        await applyPurge(
            to: context.roster.enemy.combatant,
            source: source,
            abilityName: triggerAbilityName(.cleanseAlsoPurgesEnemyBuffs, for: source, fallback: "Dispel Magic", in: context),
            count: count,
            purgeAll: false,
            in: &context,
        )
    }

    static func toxicBacklashDamage(
        source: Combatant,
        removedCount: Int,
        in context: inout BattleState,
    ) async {
        let triggers = context.modifiers(for: source.id).triggers
        guard removedCount > 0, triggers.onCleansePoisonDealDamagePerStack > 0, context.roster.enemy.isAlive else { return }
        _ = await context.dealReactionDamage(
            SaturatedArithmetic.saturatingMul(triggers.onCleansePoisonDealDamagePerStack, removedCount), to: context.roster.enemy.combatant,
            keyword: .physical, sourceActorID: source.id,
        )
    }

    static func reflectCleansedEffects(
        _ removed: [ActiveEffect],
        source: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.modifiers(for: source.id).triggers.cleanseReflectDebuffToEnemy,
              source.role != .enemy, context.roster.enemy.isAlive else { return }
        let enemy = context.roster.enemy.combatant

        for active in removed where active.sourceActorID == enemy.id {
            await ActiveEffectMutation.reflect(active, to: enemy, source: source, in: &context)
        }
    }

    static func cleanseOtherPartyMember(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.cleanseAffectsBothHeroAndCompanion,
              context.claimHeroTalent(.massCleanse, actorID: source.id)
        else { return }
        let action = BattleActionContext(actor: source, in: context)
        guard let other = action.allies(in: context).first(where: {
            $0.id != target.id && context.health(of: $0) > 0
        }) else { return }
        guard context.roster.activeEffects(for: other).contains(where: \.effect.isRemovableDebuff) else { return }
        let abilityName = triggerAbilityName(
            .cleanseAffectsBothHeroAndCompanion,
            for: source,
            fallback: "Mass Cleanse",
            in: context,
        )
        _ = await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: source, target: other, abilityName: abilityName,
            propagation: .secondary, in: &context,
        )
    }

    static func drawAfterCleanse(
        source: Combatant,
        removedCount: Int,
        in context: inout BattleState,
    ) {
        guard removedCount > 0 else { return }
        let count = context.modifiers(for: source.id).triggers.cleanseBonusDraw
        guard count > 0,
              context.claimHeroTalent(.purifyingWisdom, actorID: source.id, battle: true)
        else { return }
        guard let owner = context.roster.participant(for: source), owner.isPartyMember else {
            return
        }
        drawCards(
            count,
            for: owner,
            actor: source,
            abilityName: triggerAbilityName(.cleanseBonusDraw, for: source, fallback: "Purifying Wisdom", in: context),
            in: &context,
        )
    }
}
