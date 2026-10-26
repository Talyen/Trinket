import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterGoldTheft(by actor: Combatant, amount: Int, in context: inout BattleState) async {
        guard context.roster.health(for: actor) > 0 else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        goldTheftAllyBlock(amount, by: actor, in: &context)
        await afterCompanionGoldTheft(by: actor, in: &context)
        guard context.roster.health(for: actor) > 0 else { return }
        if triggers.goldTheftBlockAmount > 0, triggers.goldTheftBlockChancePercent > 0,
           context.claimTalentAbility(.hoardArmor, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.goldTheftBlockChancePercent, using: &context.rng) {
            context.applyBlockGain(triggers.goldTheftBlockAmount, to: actor, source: actor, abilityName: "Hoard Armor")
        }
        if triggers.goldTheftDrawChancePercent > 0,
           context.claimTalentAbility(.goldTheftChanceDraw, actorID: actor.id),
           BattleChance.succeeds(probability: triggers.goldTheftDrawChancePercent, using: &context.rng),
           let owner = context.roster.participant(for: actor) {
            drawCards(
                1, for: owner, actor: actor, abilityName: triggerAbilityName(
                    .goldTheftDrawChancePercent, for: actor, fallback: "Scavenger’s Cache", in: context,
                ), in: &context,
            )
        }
        if triggers.goldTheftDodgeBonus > 0,
           context.roster.runtime(for: actor)?.talents.turn.goldTheftDodgeApplied == false {
            context.roster.mutateRuntime(for: actor) {
                $0.talents.turn.goldTheftDodgeApplied = true
                $0.talents.grantDodgeUntilNextTurn(triggers.goldTheftDodgeBonus)
            }
        }
        prepareGoldTheftDamageBonuses(for: actor, triggers: triggers, in: &context)
        if triggers.criticalGoldStealDrawCard,
           context.resolution.hasCriticalHit(by: actor.id),
           context.claimTalentAbility(.criticalGoldTheftDraw, actorID: actor.id),
           let owner = context.roster.participant(for: actor) {
            drawCards(1, for: owner, actor: actor, abilityName: "Quick Fingers", in: &context)
        }
        if triggers.firstGoldTheftDraw > 0,
           let owner = context.roster.participant(for: actor), owner.isPartyMember,
           context.claimHeroTalent(.firstGoldTheftDraw, actorID: actor.id) {
            drawCards(
                triggers.firstGoldTheftDraw, for: owner, actor: actor,
                abilityName: triggerAbilityName(.firstGoldTheftDraw, for: actor, fallback: "Quick Fingers", in: context),
                in: &context,
            )
        }
        if triggers.firstGoldTheftHeal > 0,
           context.claimHeroTalent(.firstGoldTheftHeal, actorID: actor.id) {
            await emitHeal(
                .firstGoldTheftHeal, "Scavenger's Cache",
                amount: triggers.firstGoldTheftHeal, to: actor, source: actor, in: &context,
            )
        }
    }

    private static func goldTheftAllyBlock(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState,
    ) {
        guard actor.role == .companion, context.roster.hero.isAlive,
              context.modifiers(for: actor.id).triggers.goldTheftAllyBlock else { return }
        context.applyBlockGain(amount, to: context.roster.hero.combatant, source: actor, abilityName: "War Chest", amountBasis: .resolved)
    }

    private static func prepareGoldTheftDamageBonuses(
        for actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard triggers.goldStealNextPhysicalBonus > 0 || triggers.goldStealNextAttackBonus > 0 else { return }
        let serial = context.resolution.cardTalents?.playSerial
        let actionID = context.resolution.actionID
        context.roster.mutateRuntime(for: actor) {
            if triggers.goldStealNextPhysicalBonus > 0 {
                $0.talents.pending.nextPhysicalDamageBonus = PreparedTalentBonus(
                    value: max($0.talents.pending.nextPhysicalDamageBonus?.value ?? 0, triggers.goldStealNextPhysicalBonus),
                    cardSerial: serial, actionID: actionID,
                )
            }
            if triggers.goldStealNextAttackBonus > 0 {
                $0.talents.pending.nextAttackDamageBonus = PreparedTalentBonus(
                    value: max($0.talents.pending.nextAttackDamageBonus?.value ?? 0, triggers.goldStealNextAttackBonus),
                    cardSerial: serial, actionID: actionID,
                )
            }
        }
    }

    static func afterEnemyDefeated(in context: inout BattleState) async {
        for (_, member) in livingPartyMembers(in: context) {
            let actor = member.combatant
            let amount = context.modifiers(for: actor.id).triggers.defeatEnemyGoldFlat
            if amount > 0 {
                await emitGold(.defeatEnemyGoldFlat, "Bounty", amount: amount, to: actor, in: &context)
            }
        }
        if context.lastEnemyDefeatWasCritical,
           let sourceID = context.lastEnemyDefeatSourceActorID,
           let source = context.roster.combatant(for: sourceID), source.isAlive {
            let amount = context.modifiers(for: sourceID).triggers.critOnDefeatGold
            if amount > 0 {
                await emitGold(.critOnDefeatGold, "Bounty Hunter", amount: amount, to: source.combatant, in: &context)
            }
        }
    }

    static func afterVictory(in context: inout BattleState) async {
        for (_, member) in livingPartyMembers(in: context) {
            let actor = member.combatant
            let triggers = context.modifiers(for: actor.id).triggers
            if triggers.victoryGoldPerDifferentCardCap > 0 {
                let amount = min(triggers.victoryGoldPerDifferentCardCap, member.talents.battle.differentPlayedCardAbilityIDs.count)
                await emitGold(.victoryGoldPerDifferentCardCap, "Merchant's Favor", amount: amount, to: actor, in: &context)
            }
            if triggers.victoryGoldFlat > 0 {
                await emitGold(.victoryGoldFlat, "Smuggler's Map", amount: triggers.victoryGoldFlat, to: actor, in: &context)
            }
            if triggers.victoryGoldCoin {
                let amount = BattleChance.succeeds(probability: 0.5, using: &context.rng) ? 7 : 3
                await emitGold(.victoryGoldCoin, "Wishing Well Coin", amount: amount, to: actor, in: &context)
            }
        }
    }

    static func healLowestAfterGoldGain(
        source: Combatant,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        let amount = context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf
        guard amount > 0 else { return .empty }
        let target = BattleActionContext(actor: source, in: context).target(.lowestHealthAlly, in: context)
        return await resolveBonusHeal(
            amount: amount,
            source: source,
            target: target,
            in: &context,
        )
    }

    static func afterGoldGained(
        granted: Int,
        previousEarned: Int,
        currentEarned: Int,
        combatant: Combatant,
        in context: inout BattleState,
    ) async {
        guard granted > 0 else { return }
        await afterGoldGainRewards(granted: granted, combatant: combatant, in: &context)
        for (_, member) in livingPartyMembers(in: context) {
            let memberTriggers = context.modifiers(for: member.id).triggers
            let percent = memberTriggers.goldGainBlockPercent
            if member.id == combatant.id, percent > 0 {
                let block = CombatRounding.scaled(granted, multiplier: percent)
                if block > 0 {
                    // The Gold amount is already scaled; resolved Block avoids
                    // repeating Block-gain bonuses and fight pacing.
                    context.applyBlockGain(
                        block, to: member.combatant, source: member.combatant,
                        abilityName: triggerAbilityName(
                            .goldGainBlockPercent, for: member.combatant, fallback: "Golden Guard", in: context,
                        ),
                        amountBasis: .resolved,
                    )
                }
            }
            let every = memberTriggers.blockPerGoldEarnedEvery
            guard every > 0 else { continue }
            let newlyGranted = currentEarned / every - previousEarned / every
            if newlyGranted > 0 {
                emitBlock(
                    .blockPerGoldEarnedEvery, "Golden Guard",
                    amount: newlyGranted, to: member.combatant, source: member.combatant, in: &context,
                )
            }
        }
    }

    // swiftlint:disable:next function_body_length - recipient Gold rewards share ordered reaction checkpoints
    private static func afterGoldGainRewards(
        granted: Int,
        combatant: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: combatant) > 0 else { return }
        let triggers = context.modifiers(for: combatant.id).triggers
        let wasBelowHalfHealth = context.roster.isBelowHalfHealth(for: combatant)
        let restoration = await beginGoldRestoration(granted: granted, combatant: combatant, triggers: triggers, in: &context)
        guard context.roster.health(for: combatant) > 0 else { return }

        let hasAbilityScope = context.resolution.actionID != nil || context.hasHeroCard(for: combatant.id)
        let wildcardGoldGain = granted > 0 && context.allowsHeroTalentReaction
            && (!hasAbilityScope || context.claimTalentAbility(.wildcardGoldGain, actorID: combatant.id))
        if wildcardGoldGain {
            await healthIsWealthHealing(for: combatant, triggers: triggers, in: &context)
            guard context.roster.health(for: combatant) > 0 else { return }
            if triggers.goldGainCleanseChancePercent > 0,
               context.hasTalentDebuff(on: combatant),
               BattleChance.succeeds(probability: triggers.goldGainCleanseChancePercent, using: &context.rng) {
                await performRandomCleanses(source: combatant, target: combatant, count: 1, abilityName: "Lucky Charm", in: &context)
                guard context.roster.health(for: combatant) > 0 else { return }
            }
            if triggers.goldGainBelowHalfDrawCard, wasBelowHalfHealth,
               let owner = context.roster.participant(for: combatant) {
                drawCards(1, for: owner, actor: combatant, abilityName: "Last Wager", in: &context)
            }
            if triggers.firstGoldGainDrawCardPerTurn, context.roster.enemy.isAlive,
               let owner = context.roster.participant(for: combatant),
               context.claimHeroTalent(.firstGoldGainDraw, actorID: combatant.id) {
                drawCards(
                    1, for: owner, actor: combatant,
                    abilityName: triggerAbilityName(
                        .firstGoldGainDrawCardPerTurn, for: combatant, fallback: "Lucky Break", in: context,
                    ), in: &context,
                )
            }
            if triggers.goldGainDrawChancePercent > 0, context.roster.enemy.isAlive,
               context.claimTalentAbility(.goldGainDrawChance, actorID: combatant.id),
               BattleChance.succeeds(probability: triggers.goldGainDrawChancePercent, using: &context.rng),
               let owner = context.roster.participant(for: combatant) {
                drawCards(
                    1, for: owner, actor: combatant,
                    abilityName: triggerAbilityName(
                        .goldGainDrawChancePercent, for: combatant, fallback: "Lucky Break", in: context,
                    ), in: &context,
                )
            }
        }
        if triggers.lightFingered {
            DefensePoolEngine.steal(
                granted, from: context.roster.enemy.combatant, to: combatant,
                abilityName: "Light-Fingered", in: &context,
            )
        }
        if triggers.gainGoldDrawThreshold > 0,
           granted >= triggers.gainGoldDrawThreshold,
           let owner = context.roster.participant(for: combatant),
           owner.isPartyMember,
           context.resolution.claim(.heroTalent(.goldGainThresholdDraw), actorID: combatant.id, cadence: .turn(context.turnCount)) {
            drawCards(
                1,
                for: owner,
                actor: combatant,
                abilityName: triggerAbilityName(
                    .gainGoldDrawThreshold,
                    for: combatant,
                    fallback: "Golden Opportunity",
                    in: context,
                ),
                in: &context,
            )
        }
        if restoration {
            for (_, member) in livingPartyMembers(in: context) {
                guard context.roster.health(for: combatant) > 0 else { break }
                await emitHeal(
                    .onGainGoldHealParty, "Golden Recovery",
                    amount: triggers.onGainGoldHealParty, to: member.combatant, source: combatant, in: &context,
                )
            }
        }
    }

    private static func beginGoldRestoration(
        granted: Int,
        combatant: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async -> Bool {
        guard context.resolution.depth(.leechOverflowGold) == 0 else { return false }
        let restoresParty = granted > 0 && triggers.onGainGoldHealParty > 0
            && context.resolution.claim(.heroTalent(.goldGainPartyHeal), actorID: combatant.id, cadence: .turn(context.turnCount))
        _ = await healLowestAfterGoldGain(source: combatant, in: &context)
        guard context.roster.health(for: combatant) > 0 else { return false }
        await afterFinalCompanionGoldGain(granted: granted, actor: combatant, in: &context)
        return restoresParty
    }

    private static func healthIsWealthHealing(
        for combatant: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.resolution.depth(.leechOverflowGold) == 0,
              triggers.goldGainHealChancePercent > 0, triggers.goldGainHealAmount > 0 else { return }
        let target = BattleActionContext(actor: combatant, in: context).target(.lowestHealthAlly, in: context)
        guard context.roster.health(for: target) < context.roster.maxHealth(for: target),
              BattleChance.succeeds(probability: triggers.goldGainHealChancePercent, using: &context.rng)
        else { return }
        await context.healEmitting(amount: triggers.goldGainHealAmount, target: target, source: combatant, abilityName: "Health is Wealth")
    }
}

// MARK: - Leech

package extension CombatTriggerEngine {
    static func afterLeech(
        by actor: Combatant,
        target: Combatant?,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: actor) > 0 else { return }
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers

        if triggers.leechRestoreManaFlat > 0 {
            await emitMana(
                .leechRestoreManaFlat, "Siphoning",
                amount: context.paced(triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor, in: &context,
            )
        }

        guard context.roster.health(for: actor) > 0 else { return }
        let goldChance = triggers.leechGoldChancePercent > 0 ? triggers.leechGoldChancePercent : 0.10
        if triggers.leechGoldFlat > 0,
           BattleChance.succeeds(probability: goldChance, using: &context.rng) {
            await emitGold(.leechGoldFlat, "Blood Price", amount: triggers.leechGoldFlat, to: actor, in: &context)
        }

        guard context.roster.health(for: actor) > 0,
              let target, target.role == .enemy, context.roster.health(for: target) > 0 else { return }
        for (keyword, potency) in [
            (Keyword.poison, triggers.onLeechApplyPoison),
            (Keyword.bleed, triggers.onLeechApplyBleed),
        ] where potency > 0 {
            guard context.roster.health(for: actor) > 0, context.roster.health(for: target) > 0 else { return }
            await DoTApplicator.applyDoT(keyword: keyword, potency: potency, to: target, sourceActorID: actor.id, in: &context)
        }
        guard context.roster.health(for: actor) > 0, context.roster.health(for: target) > 0 else { return }
        if triggers.onLeechReduceEnemyStrength > 0 {
            context.insertEffect(
                .damageReductionFlat(
                    triggers.onLeechReduceEnemyStrength,
                    triggers.onLeechReduceEnemyStrengthTurns,
                ),
                to: target,
                sourceID: actor.id,
                remainingTurns: triggers.onLeechReduceEnemyStrengthTurns,
            )
        }
    }
}
