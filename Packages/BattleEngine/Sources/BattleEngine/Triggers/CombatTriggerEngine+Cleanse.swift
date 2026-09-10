import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func preventsDebuff(_ effect: Effect, on target: Combatant, in context: BattleState) -> Bool {
        guard effect.isRemovableDebuff else { return false }
        if context.roster.runtime(for: target)?.cleansedKeywordProtection.contains(effect.keyword) == true {
            return true
        }
        return effect.keyword == .burn && context.modifiers(for: target.id).triggers.undyingEmber
            && context.roster.isDeathsDoorActive(for: target)
    }

    static func performRandomCleanses(
        source: Combatant,
        target: Combatant,
        count: Int,
        abilityName: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard count > 0, context.roster.health(for: target) > 0 else { return [] }
        var events: [ActionEvent] = []
        for _ in 0 ..< count {
            let outcome = CleanseOperation.resolve(
                .random, source: source, target: target, abilityName: abilityName, in: &context,
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
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        events.append(contentsOf: cleanseShieldBonuses(
            triggers: triggers,
            source: source,
            target: target,
            removedCount: removedCount,
            allowPartyBlock: allowMassCleanse,
            in: &context,
        ))
        if allowMassCleanse {
            events.append(contentsOf: dispelMagicPurge(triggers: triggers, source: source, in: &context))
            events.append(contentsOf: cleansePartyReactions(
                triggers: triggers,
                source: source,
                target: target,
                in: &context,
            ))
        }
        if source.role != .enemy, Self.hasLivingPartyTrigger(\.purifyingWaters, in: context), removedCount > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: 4 * removedCount,
                target: target,
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
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        events.append(contentsOf: toxicBacklashDamage(
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
        var events: [ActionEvent] = []
        if triggers.cleanseBlockPerStack > 0, removedCount > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.cleanseBlockPerStack * removedCount,
                to: target,
                source: source,
                abilityName: triggerAbilityName("cleanseBlockPerStack", for: source, fallback: "Spellbreak Shield", in: context),
            ))
        }
        guard allowPartyBlock, triggers.cleansePartyBlock > 0 else { return events }
        for owner in [BattleParticipant.hero, .companion] {
            let member = context.roster[owner]
            guard member.isAlive else { continue }
            events.append(contentsOf: context.applyBlock(
                triggers.cleansePartyBlock,
                to: member.combatant,
                source: source,
                abilityName: triggerAbilityName("cleansePartyBlock", for: source, fallback: "Cleansing Ward", in: context),
            ))
        }
        return events
    }

    private static func dispelMagicPurge(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.enemy.isAlive else { return [] }
        return applyPurge(
            to: context.roster.enemy.combatant,
            source: source,
            abilityName: triggerAbilityName("cleanseAlsoPurgesEnemyBuffs", for: source, fallback: "Dispel Magic", in: context),
            count: triggers.cleanseAlsoPurgesEnemyBuffs,
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
    ) -> [ActionEvent] {
        guard triggers.onCleansePoisonDealDamagePerStack > 0, removedKeyword == .poison,
              removedCount > 0, context.roster.enemy.isAlive,
              context.roster.health(for: context.roster.enemy.combatant) > 0
        else { return [] }
        return context.resolveDamage(
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
    ) -> [ActionEvent] {
        guard context.modifiers(for: source.id).triggers.cleanseReflectDebuffToEnemy,
              source.role != .enemy, context.roster.enemy.isAlive else { return [] }
        let enemy = context.roster.enemy.combatant
        var events: [ActionEvent] = []
        for active in removed where active.sourceActorID == enemy.id {
            events.append(contentsOf: ActiveEffectMutation.reflect(active, to: enemy, source: source, in: &context))
        }
        return events
    }

    private static func cleansePartyReactions(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if triggers.cleanseDodgeChanceBonus > 0 {
            let duration = max(1, triggers.cleanseDodgeChanceBonusTurns)
            context.roster.mutateRuntime(for: target) {
                $0.bonusDodgeUntilNextTurn += triggers.cleanseDodgeChanceBonus
                $0.bonusDodgeExpiresAtTurn = max($0.bonusDodgeExpiresAtTurn, context.turnCount + duration)
            }
        }
        return cleanseOtherPartyMember(source: source, target: target, in: &context)
    }

    static func cleanseOtherPartyMember(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        guard triggers.cleanseAffectsBothHeroAndCompanion else { return [] }
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
        return CleanseOperation.resolve(
            .all(nil), source: source, target: other, abilityName: abilityName,
            propagation: .secondary, in: &context,
        ).events
    }

    static func healAfterCleanse(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseBonusHeal,
            source: source,
            target: target,
            in: &context,
        )
    }

    static func healWearerAfterCleanse(
        source: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseSelfHeal,
            source: source,
            target: source,
            in: &context,
        )
    }

    static func drawAfterCleanse(
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let count = context.modifiers(for: source.id).triggers.cleanseBonusDraw
        guard count > 0 else { return [] }
        guard let owner = context.roster.participant(for: source), owner.isPartyMember else {
            return []
        }
        return drawCards(
            count,
            for: owner,
            actor: source,
            abilityName: triggerAbilityName("cleanseBonusDraw", for: source, fallback: traitName(for: source, in: context), in: context),
            in: &context,
        )
    }
}
