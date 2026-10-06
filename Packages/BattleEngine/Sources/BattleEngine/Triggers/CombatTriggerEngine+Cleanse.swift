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
    ) async -> [ActionEvent] {
        guard count > 0, context.roster.health(for: target) > 0 else { return [] }
        var events: [ActionEvent] = []
        for _ in 0 ..< count {
            let outcome = await EffectRemovalOperation.resolveCleanse(
                .randomDebuff, source: source, target: target, abilityName: abilityName, in: &context,
            )
            events.append(contentsOf: outcome.events)
            if outcome.removed.isEmpty {
                break
            }
        }
        return events
    }

    static func afterCleanseAction(
        source: Combatant,
        target: Combatant,
        removedCount: Int,
        allowMassCleanse: Bool = true,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
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
                events.append(contentsOf: context.applyBlock(
                    triggers.cleanseSelfBlockFlat * removedCount,
                    to: source, source: source,
                    abilityName: triggerAbilityName("cleanseSelfBlockFlat", for: source, fallback: "Clearheaded", in: context),
                ))
            }
            if triggers.onCleanseRestoreMana > 0 {
                await events.append(contentsOf: emitMana(
                    "onCleanseRestoreMana", "Solace",
                    amount: triggers.onCleanseRestoreMana * removedCount, to: source, in: &context,
                ))
            }
            events.append(contentsOf: cleanseShieldBonuses(
                triggers: triggers,
                source: source,
                target: target,
                removedCount: removedCount,
                allowPartyBlock: allowMassCleanse,
                in: &context,
            ))
        }
        if allowMassCleanse {
            await events.append(contentsOf: dispelMagicPurge(triggers: triggers, source: source, in: &context))
            await events.append(contentsOf: cleansePartyReactions(
                triggers: triggers,
                source: source,
                target: target,
                in: &context,
            ))
        }
        if source.role != .enemy, Self.hasLivingPartyTrigger(\.purifyingWaters, in: context), removedCount > 0 {
            let healTarget = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
            await events.append(contentsOf: context.healEmitting(
                amount: 4 * removedCount,
                target: healTarget,
                source: source,
                abilityName: "Purifying Waters",
            ))
        }
        return events
    }

    static func afterCleanseKeywordReaction(
        source: Combatant,
        removedKeyword: Keyword,
        removedCount: Int,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        await events.append(contentsOf: toxicBacklashDamage(
            triggers: triggers,
            source: source,
            removedKeyword: removedKeyword,
            removedCount: removedCount,
            in: &context,
        ))
        return events
    }

    private static func cleanseShieldBonuses(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        removedCount: Int,
        allowPartyBlock: Bool,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard removedCount > 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.cleanseBlockPerStack > 0 {
            events.append(contentsOf: emitBlock(
                "cleanseBlockPerStack", "Spellbreak Shield",
                amount: triggers.cleanseBlockPerStack * removedCount, to: target, source: source, in: &context,
            ))
        }
        if triggers.cleanseTargetBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.cleanseTargetBlockFlat,
                to: target, source: source, abilityName: "Cleansing Ward",
            ))
        }
        guard allowPartyBlock, triggers.cleansePartyBlock > 0 else { return events }
        for (_, member) in livingPartyMembers(in: context) {
            events.append(contentsOf: emitBlock(
                "cleansePartyBlock", "Cleansing Ward",
                amount: triggers.cleansePartyBlock, to: member.combatant, source: source, in: &context,
            ))
        }
        return events
    }

    private static func dispelMagicPurge(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard context.roster.enemy.isAlive else { return [] }
        var count = triggers.cleanseAlsoPurgesEnemyBuffs
        if count == 0, triggers.cleansePurgeChancePercent > 0,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: \.effect.isRemovableBuff),
           context.claimTalentAbility(.dispelMagic, actorID: source.id),
           BattleChance.succeeds(probability: triggers.cleansePurgeChancePercent, using: &context.rng) {
            count = 1
        }
        guard count > 0 else { return [] }
        return await applyPurge(
            to: context.roster.enemy.combatant,
            source: source,
            abilityName: triggerAbilityName("cleanseAlsoPurgesEnemyBuffs", for: source, fallback: "Dispel Magic", in: context),
            count: count,
            purgeAll: false,
            in: &context,
        )
    }

    private static func toxicBacklashDamage(
        triggers: CombatTraitTriggers,
        source: Combatant,
        removedKeyword: Keyword,
        removedCount: Int,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard triggers.onCleansePoisonDealDamagePerStack > 0, removedKeyword == .poison,
              removedCount > 0, context.roster.enemy.isAlive,
              context.roster.health(for: context.roster.enemy.combatant) > 0
        else { return [] }
        return await context.resolveDamage(
            DamageRequest(
                amount: triggers.onCleansePoisonDealDamagePerStack * removedCount,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: source.id,
                options: .reaction(),
            ),
        ).events
    }

    static func reflectCleansedEffects(
        _ removed: [ActiveEffect],
        source: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard context.modifiers(for: source.id).triggers.cleanseReflectDebuffToEnemy,
              source.role != .enemy, context.roster.enemy.isAlive else { return [] }
        let enemy = context.roster.enemy.combatant
        var events: [ActionEvent] = []
        for active in removed where active.sourceActorID == enemy.id {
            await events.append(contentsOf: ActiveEffectMutation.reflect(active, to: enemy, source: source, in: &context))
        }
        return events
    }

    private static func cleansePartyReactions(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        if triggers.cleanseDodgeChanceBonus > 0 {
            EffectRemovalOperation.grantSecondaryCleanseDodge(source: source, target: target, in: &context)
        }
        return await cleanseOtherPartyMember(source: source, target: target, in: &context)
    }

    static func cleanseOtherPartyMember(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.cleanseAffectsBothHeroAndCompanion,
              context.claimHeroTalent(.massCleanse, actorID: source.id)
        else { return [] }
        let action = BattleActionContext(actor: source, in: context)
        guard let other = action.allies(in: context).first(where: {
            $0.id != target.id && context.health(of: $0) > 0
        }) else { return [] }
        guard context.roster.activeEffects(for: other).contains(where: \.effect.isRemovableDebuff) else { return [] }
        let abilityName = triggerAbilityName(
            "cleanseAffectsBothHeroAndCompanion",
            for: source,
            fallback: "Mass Cleanse",
            in: context,
        )
        return await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: source, target: other, abilityName: abilityName,
            propagation: .secondary, in: &context,
        ).events
    }

    static func bonusHealAfterCleanse(
        source: Combatant,
        target: Combatant,
        amount: Int,
        requireWoundedTarget: Bool,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard amount > 0 else { return .empty }
        if requireWoundedTarget {
            guard context.roster.health(for: target) < context.roster.maxHealth(for: target) else { return .empty }
        }
        return await resolveBonusHeal(
            amount: amount,
            source: source,
            target: target,
            in: &context,
        )
    }

    static func drawAfterCleanse(
        source: Combatant,
        removedCount: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard removedCount > 0 else { return [] }
        let count = context.modifiers(for: source.id).triggers.cleanseBonusDraw
        guard count > 0,
              context.claimHeroTalent(.purifyingWisdom, actorID: source.id, battle: true)
        else { return [] }
        guard let owner = context.roster.participant(for: source), owner.isPartyMember else {
            return []
        }
        return drawCards(
            count,
            for: owner,
            actor: source,
            abilityName: triggerAbilityName("cleanseBonusDraw", for: source, fallback: "Purifying Wisdom", in: context),
            in: &context,
        )
    }
}
