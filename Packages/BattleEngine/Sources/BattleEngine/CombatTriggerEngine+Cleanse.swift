import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Removes up to `count` random debuffs from `target`, logs each cleanse, and
    /// runs heal/draw plus `afterCleansePerformed` for every removal.
    static func performRandomCleanses(
        source: Combatant,
        target: Combatant,
        count: Int,
        abilityName: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard count > 0, context.roster.health(for: target) > 0 else { return [] }
        var events: [ActionEvent] = []
        for _ in 0 ..< count {
            var effects = context.roster.activeEffects(for: target)
            guard let removedKeyword = EffectRemoval.removeRandomDebuff(
                from: &effects,
                using: &context.rng
            ) else { break }
            context.roster.setActiveEffects(effects, for: target)
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: removedKeyword
            ))
            events.append(contentsOf: healAfterCleanse(
                source: source,
                target: target,
                in: &context
            ).events)
            events.append(contentsOf: healWearerAfterCleanse(
                source: source,
                in: &context
            ).events)
            events.append(contentsOf: drawAfterCleanse(
                source: source,
                in: &context
            ))
            events.append(contentsOf: afterCleansePerformed(
                source: source,
                target: target,
                removedKeyword: removedKeyword,
                removedCount: 1,
                in: &context
            ))
        }
        return events
    }

    /// Reactions after a cleanse removes debuffs from `target` (Combatant Talent System).
    static func afterCleansePerformed(
        source: Combatant,
        target: Combatant,
        removedKeyword: Keyword,
        removedCount: Int,
        allowMassCleanse: Bool = true,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: source.id).triggers
        var events: [ActionEvent] = []
        events.append(contentsOf: cleanseShieldBonuses(
            triggers: triggers,
            source: source,
            target: target,
            removedCount: removedCount,
            in: &context
        ))
        events.append(contentsOf: cleanseEnemyReactions(
            triggers: triggers,
            source: source,
            removedKeyword: removedKeyword,
            removedCount: removedCount,
            in: &context
        ))
        if allowMassCleanse {
            events.append(contentsOf: cleansePartyReactions(
                triggers: triggers,
                source: source,
                target: target,
                in: &context
            ))
        }
        return events
    }

    /// Spellbreak Shield and Cleansing Ward: Block from cleansing.
    private static func cleanseShieldBonuses(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        removedCount: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.cleanseBlockPerStack > 0, removedCount > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.cleanseBlockPerStack * removedCount,
                to: target,
                source: source,
                abilityName: triggerAbilityName("cleanseBlockPerStack", for: source, fallback: "Spellbreak Shield", in: context)
            ))
        }
        if triggers.cleansePartyBlock > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                events.append(contentsOf: context.applyBlock(
                    triggers.cleansePartyBlock,
                    to: member.combatant,
                    source: source,
                    abilityName: triggerAbilityName("cleansePartyBlock", for: source, fallback: "Cleansing Ward", in: context)
                ))
            }
        }
        return events
    }

    /// Dispel Magic, Toxic Backlash, and Reflective Ward: enemy-facing reactions.
    private static func cleanseEnemyReactions(
        triggers: CombatTraitTriggers,
        source: Combatant,
        removedKeyword: Keyword,
        removedCount: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        events.append(contentsOf: dispelMagicPurge(triggers: triggers, source: source, in: &context))
        events.append(contentsOf: toxicBacklashDamage(
            triggers: triggers,
            source: source,
            removedKeyword: removedKeyword,
            removedCount: removedCount,
            in: &context
        ))
        events.append(contentsOf: reflectiveWardReflect(triggers: triggers, source: source, removedKeyword: removedKeyword, in: &context))
        return events
    }

    /// Dispel Magic: cleanse also purges 1 enemy buff.
    private static func dispelMagicPurge(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.cleanseAlsoPurgesEnemyBuffs > 0, context.roster.enemy.isAlive else { return [] }
        var enemyEffects = context.roster.activeEffects(for: context.roster.enemy.combatant)
        let removedBuffs = EffectRemoval.removeBuffs(
            from: &enemyEffects,
            count: triggers.cleanseAlsoPurgesEnemyBuffs,
            removeAll: false,
            using: &context.rng
        )
        guard !removedBuffs.isEmpty else { return [] }
        context.roster.setActiveEffects(enemyEffects, for: context.roster.enemy.combatant)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: triggerAbilityName("cleanseAlsoPurgesEnemyBuffs", for: source, fallback: "Dispel Magic", in: context),
            target: context.roster.enemy.combatant,
            amount: 0,
            keyword: removedBuffs[0]
        )]
    }

    /// Toxic Backlash: cleansing Poison deals damage per cleansed potency point.
    private static func toxicBacklashDamage(
        triggers: CombatTraitTriggers,
        source: Combatant,
        removedKeyword: Keyword,
        removedCount: Int,
        in context: inout BattleState
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
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        ).events
    }

    /// Reflective Ward: cleansing reflects a matching DoT onto the enemy.
    private static func reflectiveWardReflect(
        triggers: CombatTraitTriggers,
        source: Combatant,
        removedKeyword: Keyword,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard triggers.cleanseReflectDebuffToEnemy, context.roster.enemy.isAlive,
              context.roster.health(for: context.roster.enemy.combatant) > 0,
              removedKeyword == .burn || removedKeyword == .poison || removedKeyword == .bleed
        else { return [] }
        if removedKeyword == .bleed {
            return DoTApplicator.applyBleed(
                potency: 1,
                to: context.roster.enemy.combatant,
                sourceActorID: source.id,
                dealImmediateDamage: false,
                suppressAffixReactions: true,
                in: &context
            )
        }
        return context.applyDecayingDoT(
            keyword: removedKeyword,
            potency: 1,
            to: context.roster.enemy.combatant,
            sourceActorID: source.id,
            dealImmediateDamage: false,
            suppressAffixReactions: true
        )
    }

    /// Fae Swiftness and Mass Cleanse: party-facing reactions.
    private static func cleansePartyReactions(
        triggers: CombatTraitTriggers,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        // Fae Swiftness: cleansing grants the target Dodge for N turns (default 1).
        if triggers.cleanseDodgeChanceBonus > 0 {
            let duration = max(1, triggers.cleanseDodgeChanceBonusTurns)
            context.roster.mutateRuntime(for: target) {
                $0.bonusDodgeUntilNextTurn += triggers.cleanseDodgeChanceBonus
                $0.bonusDodgeExpiresAtTurn = max($0.bonusDodgeExpiresAtTurn, context.turnCount + duration)
            }
        }
        // Mass Cleanse: the owner's cleanses also cleanse the other party member.
        guard triggers.cleanseAffectsBothHeroAndCompanion else { return [] }
        let other = target.role == .hero
            ? context.roster.companion.combatant
            : context.roster.hero.combatant
        guard other.id != target.id, context.roster.health(for: other) > 0 else { return [] }
        var effects = context.roster.activeEffects(for: other)
        let removedDebuffs = effects.filter(\.effect.isRemovableDebuff)
        guard EffectRemoval.removeDebuffs(from: &effects, keyword: nil) else { return [] }
        context.roster.setActiveEffects(effects, for: other)
        let abilityName = triggerAbilityName(
            "cleanseAffectsBothHeroAndCompanion",
            for: source,
            fallback: "Mass Cleanse",
            in: context
        )
        var countsByKeyword: [Keyword: Int] = [:]
        for debuff in removedDebuffs {
            countsByKeyword[debuff.keyword, default: 0] += 1
        }
        var events: [ActionEvent] = []
        for (keyword, count) in countsByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: other,
                amount: 0,
                keyword: keyword
            ))
            events.append(contentsOf: afterCleansePerformed(
                source: source,
                target: other,
                removedKeyword: keyword,
                removedCount: count,
                allowMassCleanse: false,
                in: &context
            ))
        }
        return events
    }

    static func healAfterCleanse(
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseBonusHeal,
            source: source,
            target: target,
            in: &context
        )
    }

    static func healWearerAfterCleanse(
        source: Combatant,
        in context: inout BattleState
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.cleanseSelfHeal,
            source: source,
            target: source,
            in: &context
        )
    }

    static func drawAfterCleanse(
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let count = context.modifiers(for: source.id).triggers.cleanseBonusDraw
        guard count > 0 else { return [] }
        guard let owner = context.roster.participant(for: source), owner.isPartyMember else {
            return []
        }
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: source.name,
            abilityName: triggerAbilityName("cleanseBonusDraw", for: source, fallback: traitName(for: source, in: context), in: context),
            target: source,
            amount: drawn,
            keyword: .physical
        )]
    }
}
