import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
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
                removedKeyword: removedKeyword,
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
                abilityName: "Spellbreak Shield"
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
                    abilityName: "Cleansing Ward"
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
            abilityName: "Dispel Magic",
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
        removedKeyword: Keyword,
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
        let beforeCount = effects.count
        guard EffectRemoval.removeDebuffs(from: &effects, keyword: nil) else { return [] }
        context.roster.setActiveEffects(effects, for: other)
        let massRemoved = max(1, beforeCount - effects.count)
        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: "Mass Cleanse",
            target: other,
            amount: 0,
            keyword: removedKeyword
        )]
        events.append(contentsOf: afterCleansePerformed(
            source: source,
            target: other,
            removedKeyword: removedKeyword,
            removedCount: massRemoved,
            allowMassCleanse: false,
            in: &context
        ))
        return events
    }

    static func afterCardPlayed(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []

        // Dazing Swipe: chance to delay the enemy's turn when a card is played.
        if triggers.attackDelayEnemyTurnChancePercent > 0, context.roster.enemy.isAlive,
           BattleChance.succeeds(probability: triggers.attackDelayEnemyTurnChancePercent, using: &context.rng) {
            context.additionalControlSkipsByCombatantID[context.roster.enemy.id, default: 0] += 1
        }

        guard triggers.cardsPlayedManaThreshold > 0, triggers.cardsPlayedManaFlat > 0 else { return events }
        let count = context.cardsPlayedThisTurn[owner, default: 0] + 1
        context.cardsPlayedThisTurn[owner] = count
        guard count == triggers.cardsPlayedManaThreshold else { return events }

        let restored = context.restoreMana(triggers.cardsPlayedManaFlat, to: actor)
        guard restored > 0 else { return events }
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: actor.name,
            abilityName: "Resonant Chimes",
            target: actor,
            amount: restored,
            keyword: .mana
        ))
        events.append(contentsOf: afterGainMana(by: actor, in: &context))
        return events
    }

    static func drawAfterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnSpendMana
        guard count > 0, context.spendManaDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(count, for: owner, actor: actor, abilityName: "Runic Quill", in: &context)
    }

    static func drawAfterHealthLoss(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return [] }
        let count = context.modifiers(for: actor.id).triggers.drawOnHealthLoss
        guard count > 0, context.healthLossDrawOwnersThisTurn.insert(owner).inserted else { return [] }
        return drawCards(count, for: owner, actor: actor, abilityName: "Bone Charm", in: &context)
    }

    static func afterHealthRestored(
        _ amount: Int,
        to actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.healthRestoredPoisonPercent
        guard amount > 0, percent > 0, context.roster.enemy.isAlive, !context.isResolvingTrinketReaction else {
            return []
        }
        let damage = CombatRounding.scaled(amount, multiplier: percent)
        guard damage > 0 else { return [] }
        context.isResolvingTrinketReaction = true
        defer { context.isResolvingTrinketReaction = false }
        return context.resolveDamage(
            DamageRequest(
                amount: damage,
                target: context.roster.enemy.combatant,
                keyword: .poison,
                sourceActorID: actor.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true
                )
            )
        ).events
    }

    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.modifiers(for: actor.id).triggers.blockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard amount > 0, gained > 0 else { return [] }

        var effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        effects.removeAll {
            if case .thorns = $0.effect {
                return true
            }
            return false
        }
        let total = existing + gained
        effects.append(ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .thorns(total),
            remainingTurns: 0,
            sourceActorID: actor.id
        ))
        context.roster.setActiveEffects(effects, for: actor)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: "Thorns",
            target: actor,
            amount: total,
            keyword: .physical
        )]
    }

    static func afterVictory(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for actor in [context.roster.hero.combatant, context.roster.companion.combatant] {
            let triggers = context.modifiers(for: actor.id).triggers
            if triggers.victoryGoldFlat > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    triggers.victoryGoldFlat,
                    to: actor,
                    abilityName: "Smuggler's Map"
                ))
            }
            if triggers.victoryGoldCoin {
                if Bool.random(using: &context.rng) {
                    events.append(contentsOf: context.grantGoldEvent(7, to: actor, abilityName: "Wishing Well Coin"))
                } else {
                    let loss = min(3, max(0, context.gold))
                    guard loss > 0 else { continue }
                    context.gold -= loss
                    events.append(context.nextEvent(
                        kind: .effect,
                        effectKind: .resourceGain,
                        actorName: actor.name,
                        abilityName: "Wishing Well Coin",
                        target: actor,
                        amount: -loss,
                        keyword: .gold
                    ))
                }
            }
        }
        return events
    }

    static func drawCards(
        _ count: Int,
        for owner: BattleParticipant,
        actor: Combatant,
        abilityName: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: actor.name,
            abilityName: abilityName,
            target: actor,
            amount: drawn,
            keyword: .physical
        )]
    }
}
