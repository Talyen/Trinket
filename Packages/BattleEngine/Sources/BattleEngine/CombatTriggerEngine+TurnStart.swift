import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func turnBlock(
        for combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        guard profile.triggers.blockPerTurn > 0,
              context.roster.health(for: combatant) > 0
        else { return [] }

        let applied = DefensePoolEngine.add(
            profile.triggers.blockPerTurn,
            to: combatant,
            keyword: .block,
            sourceActorID: combatant.id,
            in: &context,
        )
        return [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: combatant.name,
            abilityName: triggerAbilityName(
                "blockPerTurn",
                for: combatant,
                fallback: traitName(for: combatant, in: context),
                in: context,
            ),
            target: combatant,
            amount: applied,
            keyword: .block,
        )]
    }

    static func atPlayerTurnStart(in context: inout BattleState) -> [ActionEvent] {
        resetTurnCadenceState(in: &context)
        var events = cleanseTeamIfNeeded(in: &context)
        for owner in [BattleParticipant.hero, .companion] {
            let runtime = context.roster[owner]
            guard runtime.isAlive else { continue }
            events.append(contentsOf: startOfTurnCadence(for: owner, runtime: runtime, in: &context))
        }
        return events
    }

    private static func resetTurnCadenceState(in context: inout BattleState) {
        context.turnCadence.reset()
        for owner in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[owner].combatant) { runtime in
                runtime.resetTalentTurnState(currentTurn: context.turnCount)
            }
        }
    }

    private static func cleanseTeamIfNeeded(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            let sourceRuntime = context.roster[owner]
            guard sourceRuntime.isAlive else { continue }
            let count = context.modifiers(for: sourceRuntime.id).triggers.autoCleanseTeamPerTurn
            guard count > 0 else { continue }
            let abilityName = triggerAbilityName(
                "autoCleanseTeamPerTurn",
                for: sourceRuntime.combatant,
                fallback: traitName(for: sourceRuntime.combatant, in: context),
                in: context,
            )
            for targetOwner in [BattleParticipant.hero, .companion] {
                let target = context.roster[targetOwner]
                guard target.isAlive else { continue }
                events.append(contentsOf: performRandomCleanses(
                    source: sourceRuntime.combatant,
                    target: target.combatant,
                    count: count,
                    abilityName: abilityName,
                    in: &context,
                ))
            }
        }
        return events
    }

    private static func startOfTurnCadence(
        for owner: BattleParticipant,
        runtime: CombatantRuntime,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let actor = runtime.combatant
        let triggers = context.modifiers(for: actor.id).triggers
        var events: [ActionEvent] = []
        events.append(contentsOf: startOfTurnRegen(runtime: runtime, actor: actor, triggers: triggers, in: &context))
        if context.turnCount.isMultiple(of: 2), triggers.drawEveryOtherTurn > 0 {
            events.append(contentsOf: drawCards(
                triggers.drawEveryOtherTurn,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName("drawEveryOtherTurn", for: actor, fallback: "Tattered Pages", in: context),
                in: &context,
            ))
        }
        if triggers.companionCardsPerTurn > 0 {
            events.append(contentsOf: drawCards(
                triggers.companionCardsPerTurn,
                for: .companion,
                actor: actor,
                abilityName: triggerAbilityName(
                    "companionCardsPerTurn",
                    for: actor,
                    fallback: "Companion's Collar",
                    in: context,
                ),
                in: &context,
            ))
        }

        events.append(contentsOf: startOfTurnAfflictionCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: startOfTurnResourceCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: startOfTurnDrawCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: battleStartBonuses(for: owner, actor: actor, triggers: triggers, in: &context))
        applyDamageRamp(for: actor, triggers: triggers, in: &context)
        return events
    }

    private static func applyDamageRamp(
        for actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        let burnPerRound: Int = triggers.burnDamageRampPerRound
        let burnCap: Int = triggers.burnDamageRampCap
        let bleedPerRound: Int = triggers.bleedDamageRampPerRound
        let bleedCap: Int = triggers.bleedDamageRampCap
        bumpDamageRamp(for: actor, keyword: Keyword.burn, perRound: burnPerRound, cap: burnCap, in: &context)
        bumpDamageRamp(for: actor, keyword: Keyword.bleed, perRound: bleedPerRound, cap: bleedCap, in: &context)
    }

    private static func bumpDamageRamp(
        for actor: Combatant,
        keyword: Keyword,
        perRound: Int,
        cap: Int,
        in context: inout BattleState,
    ) {
        guard perRound > 0, cap > 0 else { return }
        context.roster.mutateRuntime(for: actor) { runtime in
            let current: Int = runtime.keywordDamageRamp[keyword, default: 0]
            var ramp: [Keyword: Int] = runtime.keywordDamageRamp
            ramp[keyword] = min(current + perRound, cap)
            runtime.keywordDamageRamp = ramp
        }
    }

    private static func startOfTurnRegen(
        runtime: CombatantRuntime,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.goldPerTurn > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.goldPerTurn,
                to: actor,
                abilityName: triggerAbilityName("goldPerTurn", for: actor, fallback: "Merchant's Favor", in: context),
            ))
        }
        if triggers.healthPerTurn > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthPerTurn,
                target: actor,
                source: actor,
                abilityName: triggerAbilityName("healthPerTurn", for: actor, fallback: "Grove's Favor", in: context),
            ))
        }
        if runtime.healOverTimeTurnsRemaining > 0, runtime.healOverTimeAmount > 0 {
            let amount = runtime.healOverTimeAmount
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: amount,
                    target: actor,
                    sourceActorID: actor.id,
                    logAs: .instantHeal(
                        actorName: actor.name,
                        abilityName: "Lingering Blessing",
                        keyword: .health,
                    ),
                    isHoTTick: true,
                ),
                in: &context,
            ).events)
            context.roster.mutateRuntime(for: actor) {
                $0.healOverTimeTurnsRemaining -= 1
                if $0.healOverTimeTurnsRemaining <= 0 {
                    $0.healOverTimeAmount = 0
                }
            }
        }
        return events
    }

    private static func startOfTurnAfflictionCadence(
        for _: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.goldEveryNTurnsInterval > 0,
           context.turnCount > 0,
           context.turnCount.isMultiple(of: triggers.goldEveryNTurnsInterval) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.goldEveryNTurnsAmount,
                to: actor,
                abilityName: triggerAbilityName("goldEveryNTurnsAmount", for: actor, fallback: "Dig for Treasure", in: context),
            ))
        }
        if triggers.healthRegenFirstTurnsDuration > 0,
           context.turnCount < triggers.healthRegenFirstTurnsDuration {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthRegenFirstTurnsAmount,
                target: actor,
                source: actor,
                abilityName: triggerAbilityName("healthRegenFirstTurnsAmount", for: actor, fallback: "Sprite Touch", in: context),
            ))
        }
        if triggers.healthRegenAboveHalfHealth > 0,
           context.roster.maxHealth(for: actor) > 0,
           context.roster.health(for: actor) * 2 >= context.roster.maxHealth(for: actor) {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthRegenAboveHalfHealth,
                target: actor,
                source: actor,
                abilityName: triggerAbilityName("healthRegenAboveHalfHealth", for: actor, fallback: "Safe Perch", in: context),
            ))
        }
        return events
    }

    private static func startOfTurnResourceCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.startTurnFullManaDrawCards > 0,
           let runtime = context.roster.runtime(for: actor),
           runtime.maxMana > 0,
           runtime.currentMana >= runtime.maxMana {
            let drawn = BattleCardCombatEngine.drawCards(
                count: triggers.startTurnFullManaDrawCards,
                for: owner,
                context: &context,
            )
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: triggerAbilityName(
                        "startTurnFullManaDrawCards",
                        for: actor,
                        fallback: "Arcane Surge",
                        in: context,
                    ),
                    target: actor,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }
        if triggers.bonusManaOnTurns.contains(context.turnCount + 1) {
            events.append(contentsOf: context.restoreManaEmitting(
                1,
                to: actor,
                abilityName: triggerAbilityName("bonusManaOnTurns", for: actor, fallback: "Aetherial Surge", in: context),
            ))
        }
        return events
    }

    private static func startOfTurnDrawCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.extraCardDrawWhileEnemyBleeding, context.roster.enemy.isAlive,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: { $0.effect.keyword == .bleed }) {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: triggerAbilityName(
                        "extraCardDrawWhileEnemyBleeding",
                        for: actor,
                        fallback: "Frenzied Tail",
                        in: context,
                    ),
                    target: actor,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }
        if triggers.extraCardDrawBelowEnemyHealthPercent > 0, context.roster.enemy.isAlive,
           context.roster.maxHealth(for: context.roster.enemy.combatant) > 0,
           Double(context.roster.health(for: context.roster.enemy.combatant))
           / Double(context.roster.maxHealth(for: context.roster.enemy.combatant))
           < triggers.extraCardDrawBelowEnemyHealthPercent {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: triggerAbilityName(
                        "extraCardDrawBelowEnemyHealthPercent",
                        for: actor,
                        fallback: "Feral Frenzy",
                        in: context,
                    ),
                    target: actor,
                    amount: drawn,
                    keyword: .physical,
                ))
            }
        }
        return events
    }

    private static func battleStartBonuses(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.everyNTurnsFreezeAllEnemiesInterval > 0,
           context.turnCount > 0,
           context.turnCount.isMultiple(of: triggers.everyNTurnsFreezeAllEnemiesInterval),
           context.roster.enemy.isAlive {
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.everyNTurnsFreezeAllEnemiesAmount,
                keyword: .freeze,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.everyNTurnsStunBuildupInterval > 0,
           context.turnCount > 0,
           context.turnCount.isMultiple(of: triggers.everyNTurnsStunBuildupInterval),
           context.roster.enemy.isAlive {
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.everyNTurnsStunBuildupAmount,
                keyword: .stun,
                to: context.roster.enemy.combatant,
                sourceActorID: actor.id,
                applyFightPacing: false,
                in: &context,
            ))
            if triggers.everyNTurnsTeamBlockAmount > 0 {
                for memberOwner in [BattleParticipant.hero, .companion] {
                    let member = context.roster[memberOwner]
                    guard member.isAlive else { continue }
                    events.append(contentsOf: context.applyBlock(
                        triggers.everyNTurnsTeamBlockAmount,
                        to: member.combatant,
                        source: actor,
                        abilityName: triggerAbilityName(
                            "everyNTurnsTeamBlockAmount",
                            for: actor,
                            fallback: "Quaking Carapace",
                            in: context,
                        ),
                    ))
                }
            }
        }
        events.append(contentsOf: turnZeroBonuses(for: owner, actor: actor, triggers: triggers, in: &context))
        return events
    }

    private static func turnZeroBonuses(
        for _: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.turnCount == 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.startBattleBonusMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.startBattleBonusMana,
                to: actor,
                abilityName: triggerAbilityName("startBattleBonusMana", for: actor, fallback: "Dragon Spark", in: context),
            ))
        }
        if triggers.startBattleBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.startBattleBlock,
                to: actor,
                source: actor,
                abilityName: triggerAbilityName("startBattleBlock", for: actor, fallback: "Watchful Eye", in: context),
            ))
        }
        if triggers.startBattleBonusGold > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.startBattleBonusGold,
                to: actor,
                abilityName: triggerAbilityName("startBattleBonusGold", for: actor, fallback: "Deep Pockets", in: context),
            ))
        }
        return events
    }
}
