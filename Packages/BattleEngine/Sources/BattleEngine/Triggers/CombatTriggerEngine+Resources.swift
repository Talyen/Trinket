import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterGoldTheft(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: actor) > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if triggers.firstGoldTheftDraw > 0,
           let owner = context.roster.participant(for: actor), owner.isPartyMember,
           context.claimHeroTalent("quickFingers", actorID: actor.id) {
            events.append(contentsOf: drawCards(
                triggers.firstGoldTheftDraw, for: owner, actor: actor,
                abilityName: triggerAbilityName("firstGoldTheftDraw", for: actor, fallback: "Quick Fingers", in: context),
                in: &context,
            ))
        }
        if triggers.firstGoldTheftHeal > 0,
           context.claimHeroTalent("scavengersCache", actorID: actor.id) {
            events.append(contentsOf: emitHeal(
                "firstGoldTheftHeal", "Scavenger's Cache",
                amount: triggers.firstGoldTheftHeal, to: actor, source: actor, in: &context,
            ))
        }
        return events
    }

    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        for (_, member) in livingPartyMembers(in: context) {
            let actor = member.combatant
            let amount = context.modifiers(for: actor.id).triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: emitGold(
                    "defeatEnemyGoldFlat", "Bounty", amount: amount, to: actor, in: &context,
                ))
            }
        }

        for owner in [BattleParticipant.hero, .companion] {
            events.append(contentsOf: afterEnemyDefeatedReactions(for: owner, in: &context))
        }
        return events
    }

    private static func afterEnemyDefeatedReactions(
        for owner: BattleParticipant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let runtime = context.roster[owner]
        guard runtime.isAlive else { return [] }
        let actor = runtime.combatant
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        if context.lastEnemyDefeatWasCritical {
            events.append(contentsOf: critOnDefeatRewards(
                triggers: triggers,
                actor: actor,
                in: &context,
            ))
        }
        return events
    }

    private static func critOnDefeatRewards(
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.critOnDefeatGold > 0 {
            events.append(contentsOf: emitGold(
                "critOnDefeatGold", "Bounty Hunter", amount: triggers.critOnDefeatGold, to: actor, in: &context,
            ))
        }
        return events
    }

    static func afterVictory(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for actor in [context.roster.hero.combatant, context.roster.companion.combatant] {
            let triggers = context.modifiers(for: actor.id).triggers
            if triggers.victoryGoldFlat > 0 {
                events.append(contentsOf: emitGold(
                    "victoryGoldFlat", "Smuggler's Map", amount: triggers.victoryGoldFlat, to: actor, in: &context,
                ))
            }
            if triggers.victoryGoldCoin {
                if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                    events.append(contentsOf: emitGold(
                        "victoryGoldCoin", "Wishing Well Coin", amount: 7, to: actor, in: &context,
                    ))
                } else {
                    events.append(contentsOf: emitGold(
                        "victoryGoldCoin", "Wishing Well Coin", amount: 3, to: actor, in: &context,
                    ))
                }
            }
        }
        return events
    }

    static func healSelfAfterGoldGain(
        source: Combatant,
        in context: inout BattleState,
    ) -> CombatOutcome {
        resolveBonusHeal(
            amount: context.modifiers(for: source.id).triggers.gainGoldBonusHealSelf,
            source: source,
            target: source,
            in: &context,
        )
    }

    // swiftlint:disable:next function_body_length - gold trigger fan-out is one ordered transaction
    static func goldGainTriggerEvents(
        granted: Int,
        previousEarned: Int,
        currentEarned: Int,
        combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let triggers = context.modifiers(for: combatant.id).triggers
        let restoresParty = granted > 0 && triggers.onGainGoldHealParty > 0
            && context.resolution.claim(.heroTalent("goldenRecovery"), actorID: combatant.id, cadence: .turn(context.turnCount))
        var events = healSelfAfterGoldGain(source: combatant, in: &context).events
        if triggers.lightFingered {
            events.append(contentsOf: DefensePoolEngine.steal(
                granted, from: context.roster.enemy.combatant, to: combatant,
                abilityName: "Light-Fingered", in: &context,
            ))
        }
        if triggers.gainGoldDrawThreshold > 0,
           granted >= triggers.gainGoldDrawThreshold,
           let owner = context.roster.participant(for: combatant),
           owner.isPartyMember,
           context.resolution.claim(.heroTalent("goldenOpportunity"), actorID: combatant.id, cadence: .turn(context.turnCount)) {
            events.append(contentsOf: drawCards(
                1,
                for: owner,
                actor: combatant,
                abilityName: triggerAbilityName(
                    "gainGoldDrawThreshold",
                    for: combatant,
                    fallback: "Golden Opportunity",
                    in: context,
                ),
                in: &context,
            ))
        }
        if restoresParty {
            for (_, member) in livingPartyMembers(in: context) {
                events.append(contentsOf: emitHeal(
                    "onGainGoldHealParty", "Golden Recovery",
                    amount: triggers.onGainGoldHealParty, to: member.combatant, source: combatant, in: &context,
                ))
            }
        }
        if granted > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                let percent = context.modifiers(for: member.id).triggers.goldGainBlockPercent
                if percent > 0 {
                    let block = Int((Double(granted) * percent).rounded(.down))
                    if block > 0 {
                        events.append(contentsOf: emitBlock(
                            "goldGainBlockPercent", "Golden Guard",
                            amount: block, to: member.combatant, source: member.combatant, in: &context,
                        ))
                    }
                    continue
                }
                let every = context.modifiers(for: member.id).triggers.blockPerGoldEarnedEvery
                guard every > 0 else { continue }
                let newlyGranted = currentEarned / every - previousEarned / every
                if newlyGranted > 0 {
                    events.append(contentsOf: emitBlock(
                        "blockPerGoldEarnedEvery", "Golden Guard",
                        amount: newlyGranted, to: member.combatant, source: member.combatant, in: &context,
                    ))
                }
            }
        }
        return events
    }
}

// MARK: - Leech

package extension CombatTriggerEngine {
    static func afterLeech(
        by actor: Combatant,
        target: Combatant?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        var events: [ActionEvent] = []

        if triggers.leechRestoreManaFlat > 0 {
            events.append(contentsOf: emitMana(
                "leechRestoreManaFlat", "Siphoning",
                amount: context.paced(triggers.leechRestoreManaFlat, sourceActorID: actor.id),
                to: actor, in: &context,
            ))
        }

        if triggers.leechGoldFlat > 0 {
            events.append(contentsOf: emitGold(
                "leechGoldFlat", "Blood Price", amount: triggers.leechGoldFlat, to: actor, in: &context,
            ))
        }

        guard let target, target.role == .enemy, context.roster.health(for: target) > 0 else { return events }
        for (keyword, potency) in [
            (Keyword.poison, triggers.onLeechApplyPoison),
            (Keyword.bleed, triggers.onLeechApplyBleed),
        ] where potency > 0 {
            events.append(contentsOf: applyDoT(
                keyword: keyword,
                potency: potency,
                to: target,
                sourceActorID: actor.id,
                in: &context,
            ))
        }
        if triggers.onLeechReduceEnemyStrength > 0 {
            context.appendEffect(
                .damageReductionFlat(
                    triggers.onLeechReduceEnemyStrength,
                    triggers.onLeechReduceEnemyStrengthTurns,
                ),
                to: target,
                sourceID: actor.id,
                remainingTurns: triggers.onLeechReduceEnemyStrengthTurns,
            )
        }

        return events
    }
}
