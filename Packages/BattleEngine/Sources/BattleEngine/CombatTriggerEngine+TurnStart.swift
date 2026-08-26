import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    /// Bastion / Carapace: Block granted once per round during effect cadence.
    static func turnBlock(
        for combatant: Combatant,
        in context: inout BattleState
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
            in: &context
        )
        return [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: combatant.name,
            abilityName: triggerAbilityName(
                "blockPerTurn",
                for: combatant,
                fallback: traitName(for: combatant, in: context),
                in: context
            ),
            target: combatant,
            amount: applied,
            keyword: .block
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

    /// Resets per-round runtime state and draw/gold owner sets.
    private static func resetTurnCadenceState(in context: inout BattleState) {
        context.turnCadence.reset()

        // Talent per-turn runtime state: Dodge bonuses and the attack-hit flag reset
        // each round; pending one-shot dodge effects are consumed on the next hit.
        for owner in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[owner].combatant) { runtime in
                if runtime.bonusDodgeExpiresAtTurn == 0 || context.turnCount >= runtime.bonusDodgeExpiresAtTurn {
                    runtime.bonusDodgeUntilNextTurn = 0
                    runtime.bonusDodgeExpiresAtTurn = 0
                }
                runtime.hasTakenAttackHitThisTurn = false
                runtime.faeWardBlockedThisTurn = false
                runtime.hasTriggeredSaintfallThisTurn = false
            }
        }
    }

    /// Sanctified Scroll: each living owner cleanses N debuffs from each living ally.
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
                in: context
            )
            for targetOwner in [BattleParticipant.hero, .companion] {
                let target = context.roster[targetOwner]
                guard target.isAlive else { continue }
                events.append(contentsOf: performRandomCleanses(
                    source: sourceRuntime.combatant,
                    target: target.combatant,
                    count: count,
                    abilityName: abilityName,
                    in: &context
                ))
            }
        }
        return events
    }

    /// Per-owner start-of-turn cadence and battle-start bonuses.
    private static func startOfTurnCadence(
        for owner: BattleParticipant,
        runtime: CombatantRuntime,
        in context: inout BattleState
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
                abilityName: "Tattered Pages",
                in: &context
            ))
        }
        if triggers.companionCardsPerTurn > 0 {
            events.append(contentsOf: drawCards(
                triggers.companionCardsPerTurn,
                for: .companion,
                actor: actor,
                abilityName: "Companion's Collar",
                in: &context
            ))
        }

        events.append(contentsOf: startOfTurnAfflictionCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: startOfTurnResourceCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: startOfTurnDrawCadence(for: owner, actor: actor, triggers: triggers, in: &context))
        events.append(contentsOf: battleStartBonuses(for: owner, actor: actor, triggers: triggers, in: &context))
        return events
    }

    private static func startOfTurnRegen(
        runtime: CombatantRuntime,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.goldPerTurn > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.goldPerTurn,
                to: actor,
                abilityName: "Merchant's Favor"
            ))
        }
        if triggers.healthPerTurn > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthPerTurn,
                target: actor,
                source: actor,
                abilityName: "Grove's Favor"
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
                        keyword: .health
                    ),
                    isHoTTick: true
                ),
                in: &context
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

    /// Gold / heal cadences that fire on turn-count intervals or health conditions.
    private static func startOfTurnAfflictionCadence(
        for _: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.goldEveryNTurnsInterval > 0,
           context.turnCount > 0,
           context.turnCount.isMultiple(of: triggers.goldEveryNTurnsInterval) {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.goldEveryNTurnsAmount,
                to: actor,
                abilityName: "Dig for Treasure"
            ))
        }
        if triggers.healthRegenFirstTurnsDuration > 0,
           context.turnCount < triggers.healthRegenFirstTurnsDuration {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthRegenFirstTurnsAmount,
                target: actor,
                source: actor,
                abilityName: "Sprite Touch"
            ))
        }
        if triggers.healthRegenAboveHalfHealth > 0,
           context.roster.maxHealth(for: actor) > 0,
           context.roster.health(for: actor) * 2 >= context.roster.maxHealth(for: actor) {
            events.append(contentsOf: context.healEmitting(
                amount: triggers.healthRegenAboveHalfHealth,
                target: actor,
                source: actor,
                abilityName: "Safe Perch"
            ))
        }
        return events
    }

    /// Mana and gold start-of-turn resource gains.
    private static func startOfTurnResourceCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if triggers.startTurnFullManaDrawCards > 0,
           let runtime = context.roster.runtime(for: actor),
           runtime.maxMana > 0,
           runtime.currentMana >= runtime.maxMana {
            let drawn = BattleCardCombatEngine.drawCards(
                count: triggers.startTurnFullManaDrawCards,
                for: owner,
                context: &context
            )
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: "Arcane Surge",
                    target: actor,
                    amount: drawn,
                    keyword: .physical
                ))
            }
        }
        if triggers.bonusManaOnTurns.contains(context.turnCount + 1) {
            events.append(contentsOf: context.restoreManaEmitting(
                1,
                to: actor,
                abilityName: "Aetherial Surge"
            ))
        }
        return events
    }

    /// Extra draws from enemy-state conditions (Frenzied Tail, Feral Frenzy).
    private static func startOfTurnDrawCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        // Frenzied Tail: while an enemy is Bleeding, the owner draws 1 extra card each round.
        if triggers.extraCardDrawWhileEnemyBleeding, context.roster.enemy.isAlive,
           context.roster.activeEffects(for: context.roster.enemy.combatant).contains(where: { $0.effect.keyword == .bleed }) {
            let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
            if drawn > 0 {
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cardsDrawn,
                    actorName: actor.name,
                    abilityName: "Frenzied Tail",
                    target: actor,
                    amount: drawn,
                    keyword: .physical
                ))
            }
        }
        // Feral Frenzy: while the enemy is below the threshold, the Wolf draws 1 extra card each round.
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
                    abilityName: "Feral Frenzy",
                    target: actor,
                    amount: drawn,
                    keyword: .physical
                ))
            }
        }
        return events
    }

    /// Freezing Gale / Quaking Carapace interval charges and battle-start bonuses.
    private static func battleStartBonuses(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        // Freezing Gale: every N turns, apply Freeze buildup to the enemy.
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
                in: &context
            ))
        }
        // Quaking Carapace: every N turns, add Stun buildup to the enemy and grant the team Block.
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
                in: &context
            ))
            if triggers.everyNTurnsTeamBlockAmount > 0 {
                for memberOwner in [BattleParticipant.hero, .companion] {
                    let member = context.roster[memberOwner]
                    guard member.isAlive else { continue }
                    events.append(contentsOf: context.applyBlock(
                        triggers.everyNTurnsTeamBlockAmount,
                        to: member.combatant,
                        source: actor,
                        abilityName: "Quaking Carapace"
                    ))
                }
            }
        }
        events.append(contentsOf: turnZeroBonuses(for: owner, actor: actor, triggers: triggers, in: &context))
        return events
    }

    /// Turn-0 bonuses: extra Mana, start-of-battle Block and Gold, first-turn draw.
    private static func turnZeroBonuses(
        for _: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.turnCount == 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.startBattleBonusMana > 0 {
            events.append(contentsOf: context.restoreManaEmitting(
                triggers.startBattleBonusMana,
                to: actor,
                abilityName: "Dragon Spark"
            ))
        }
        if triggers.startBattleBlock > 0 {
            events.append(contentsOf: context.applyBlock(
                triggers.startBattleBlock,
                to: actor,
                source: actor,
                abilityName: "Watchful Eye"
            ))
        }
        if triggers.startBattleBonusGold > 0 {
            events.append(contentsOf: context.grantGoldEvent(
                triggers.startBattleBonusGold,
                to: actor,
                abilityName: "Deep Pockets"
            ))
        }
        return events
    }
}
