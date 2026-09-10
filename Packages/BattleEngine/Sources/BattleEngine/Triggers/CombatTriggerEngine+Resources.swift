import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterGoldTheft(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).triggers.firstGoldTheftHeal
        guard amount > 0, context.roster.health(for: actor) > 0,
              context.claimHeroTalent("scavengersCache", actorID: actor.id)
        else { return [] }
        return context.healEmitting(
            amount: amount, target: actor, source: actor,
            abilityName: triggerAbilityName("firstGoldTheftHeal", for: actor, fallback: "Scavenger's Cache", in: context),
        )
    }

    static func afterEnemyDefeated(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []

        if context.roster.hero.isAlive {
            let hero = context.roster.hero.combatant
            let amount = context.heroModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    amount,
                    to: hero,
                    abilityName: triggerAbilityName("defeatEnemyGoldFlat", for: hero, fallback: "Bounty", in: context),
                ))
            }
        }

        if context.roster.companion.isAlive {
            let companion = context.roster.companion.combatant
            let amount = context.companionModifiers.triggers.defeatEnemyGoldFlat
            if amount > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    amount,
                    to: companion,
                    abilityName: triggerAbilityName("defeatEnemyGoldFlat", for: companion, fallback: "Bounty", in: context),
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
            events.append(contentsOf: context.grantGoldEvent(
                triggers.critOnDefeatGold,
                to: actor,
                abilityName: triggerAbilityName("critOnDefeatGold", for: actor, fallback: "Bounty Hunter", in: context),
            ))
        }
        return events
    }

    static func afterVictory(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for actor in [context.roster.hero.combatant, context.roster.companion.combatant] {
            let triggers = context.modifiers(for: actor.id).triggers
            if triggers.victoryGoldFlat > 0 {
                events.append(contentsOf: context.grantGoldEvent(
                    triggers.victoryGoldFlat,
                    to: actor,
                    abilityName: triggerAbilityName("victoryGoldFlat", for: actor, fallback: "Smuggler's Map", in: context),
                ))
            }
            if triggers.victoryGoldCoin {
                if BattleChance.succeeds(probability: 0.5, using: &context.rng) {
                    events.append(contentsOf: context.grantGoldEvent(
                        7,
                        to: actor,
                        abilityName: triggerAbilityName("victoryGoldCoin", for: actor, fallback: "Wishing Well Coin", in: context),
                    ))
                } else {
                    events.append(contentsOf: context.grantGoldEvent(
                        3,
                        to: actor,
                        abilityName: triggerAbilityName("victoryGoldCoin", for: actor, fallback: "Wishing Well Coin", in: context),
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
        var events = healSelfAfterGoldGain(source: combatant, in: &context).events

        let triggers = context.modifiers(for: combatant.id).triggers
        if triggers.lightFingered {
            events.append(contentsOf: DefensePoolEngine.steal(
                granted, from: context.roster.enemy.combatant, to: combatant,
                abilityName: "Light-Fingered", in: &context,
            ))
        }
        if triggers.gainGoldDrawThreshold > 0,
           granted >= triggers.gainGoldDrawThreshold,
           let owner = context.roster.participant(for: combatant),
           owner.isPartyMember {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: combatant.name,
                    abilityName: triggerAbilityName(
                        "gainGoldDrawThreshold",
                        for: combatant,
                        fallback: "Golden Opportunity",
                        in: context,
                    ),
                    target: combatant,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }
        if triggers.onGainGoldHealParty > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                events.append(contentsOf: context.healEmitting(
                    amount: triggers.onGainGoldHealParty,
                    target: member.combatant,
                    source: combatant,
                    abilityName: triggerAbilityName(
                        "onGainGoldHealParty",
                        for: combatant,
                        fallback: "Golden Recovery",
                        in: context,
                    ),
                ))
            }
        }
        if triggers.onGainGoldDoubleStatusEffectsNextCard {
            context.roster.mutateRuntime(for: combatant) { $0.pendingDoubleStatusNextCard = true }
        }
        if granted > 0 {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                guard member.isAlive else { continue }
                let percent = context.modifiers(for: member.id).triggers.goldGainBlockPercent
                if percent > 0 {
                    let block = Int((Double(granted) * percent).rounded(.down))
                    if block > 0 {
                        events.append(contentsOf: context.applyBlock(
                            block,
                            to: member.combatant,
                            source: member.combatant,
                            abilityName: triggerAbilityName(
                                "goldGainBlockPercent",
                                for: member.combatant,
                                fallback: "Golden Guard",
                                in: context,
                            ),
                        ))
                    }
                    continue
                }
                let every = context.modifiers(for: member.id).triggers.blockPerGoldEarnedEvery
                guard every > 0 else { continue }
                let newlyGranted = currentEarned / every - previousEarned / every
                if newlyGranted > 0 {
                    events.append(contentsOf: context.applyBlock(
                        newlyGranted,
                        to: member.combatant,
                        source: member.combatant,
                        abilityName: triggerAbilityName(
                            "blockPerGoldEarnedEvery",
                            for: member.combatant,
                            fallback: "Golden Guard",
                            in: context,
                        ),
                    ))
                }
            }
        }
        return events
    }
}
