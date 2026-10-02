import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func turnBlock(
        for combatant: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: combatant) > 0 else { return [] }
        let profile = context.modifiers(for: combatant.id)
        var events: [ActionEvent] = []
        if profile.triggers.blockPerTurn > 0 {
            events.append(contentsOf: emitBlock(
                "blockPerTurn", "Trait",
                amount: profile.triggers.blockPerTurn, to: combatant, source: combatant, in: &context,
            ))
        }
        if profile.triggers.blockWhileGoldAmount > 0, profile.triggers.blockWhileGoldThreshold > 0,
           context.gold >= profile.triggers.blockWhileGoldThreshold {
            events.append(contentsOf: emitBlock(
                "blockWhileGoldAmount", "Golden Guard",
                amount: profile.triggers.blockWhileGoldAmount, to: combatant, source: combatant, in: &context,
            ))
        }
        return events
    }

    static func atPlayerTurnStart(in context: inout BattleState) -> [ActionEvent] {
        resetTurnCadenceState(in: &context)
        var events = startHeroTalentTurn(in: &context)
        guard !context.isBattleOver else { return events }
        events.append(contentsOf: HealingEngine.resolveHealingEchoes(in: &context))
        guard !context.isBattleOver else { return events }
        events.append(contentsOf: cleanseTeamIfNeeded(in: &context))
        for (owner, runtime) in livingPartyMembers(in: context) {
            guard !context.isBattleOver else { break }
            events.append(contentsOf: startOfTurnCadence(for: owner, runtime: runtime, in: &context))
        }
        return events
    }

    private static func resetTurnCadenceState(in context: inout BattleState) {
        context.turnCadence.reset()
        for owner in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[owner].combatant) { runtime in
                runtime.talents.beginTurn(context.turnCount)
            }
        }
    }

    private static func cleanseTeamIfNeeded(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for (owner, sourceRuntime) in livingPartyMembers(in: context) {
            guard !context.isBattleOver else { break }
            let count = context.modifiers(for: sourceRuntime.id).triggers.autoCleanseTeamPerTurn
            guard count > 0 else { continue }
            let abilityName = triggerAbilityName(
                "autoCleanseTeamPerTurn",
                for: sourceRuntime.combatant,
                fallback: "Trait",
                in: context,
            )
            for targetOwner in [BattleParticipant.hero, .companion] {
                guard !context.isBattleOver, context.roster[owner].isAlive else { break }
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

    /// The ordered start-of-turn cadence. Steps run in list order with a
    /// battle-over/alive recheck between each, since earlier reactions can
    /// defeat members or end the battle.
    private static func startOfTurnCadence(
        for owner: BattleParticipant,
        runtime: CombatantRuntime,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let actor = runtime.combatant
        let triggers = context.modifiers(for: actor.id).triggers
        let steps: [(inout BattleState) -> [ActionEvent]] = [
            { startOfTurnRegen(runtime: runtime, actor: actor, triggers: triggers, in: &$0) },
            { forbiddenKnowledgeIfNeeded(for: owner, actor: actor, triggers: triggers, in: &$0) },
            { companionCardsIfNeeded(for: owner, actor: actor, triggers: triggers, in: &$0) },
            { purifyingAuraIfNeeded(actor: actor, triggers: triggers, in: &$0) },
            { startOfTurnRecovery(actor: actor, triggers: triggers, in: &$0) },
            { startOfTurnMana(for: owner, actor: actor, triggers: triggers, in: &$0) },
            { startOfTurnDrawCadence(for: owner, actor: actor, triggers: triggers, in: &$0) },
            { startOfTurnCombatBonuses(actor: actor, triggers: triggers, in: &$0) },
        ]
        var events: [ActionEvent] = []
        for step in steps {
            events.append(contentsOf: step(&context))
            guard !context.isBattleOver, context.roster[owner].isAlive else { return events }
        }
        applyDamageRamp(for: actor, triggers: triggers, in: &context)
        return events
    }

    private static func forbiddenKnowledgeIfNeeded(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.isPlayerTurn(every: 2, startingAt: 1), triggers.forbiddenKnowledge else { return [] }
        // Resolve the Health cost before drawing; ordinary Health-cost rules apply
        // with no hidden nonlethal floor. A defeated owner cannot continue.
        var events = context.resolveDamage(DamageRequest(
            amount: 1,
            target: actor,
            keyword: nil,
            sourceActorID: actor.id,
            options: .healthCost,
        )).events
        guard context.roster.health(for: actor) > 0 else { return events }
        events.append(contentsOf: drawCards(
            1,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName("forbiddenKnowledge", for: actor, fallback: "Forbidden Knowledge", in: context),
            in: &context,
        ))
        return events
    }

    private static func companionCardsIfNeeded(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if context.isPlayerTurn(every: 2, startingAt: 1), triggers.drawEveryOtherTurn > 0 {
            events.append(contentsOf: drawCards(
                triggers.drawEveryOtherTurn,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName("drawEveryOtherTurn", for: actor, fallback: "Tattered Pages", in: context),
                in: &context,
            ))
        }
        let companionCards = triggers.companionCardsPerTurn
            + (context.isPlayerTurn(every: 2, startingAt: 1) ? triggers.companionCardsEveryOtherTurn : 0)
        guard companionCards > 0 else { return events }
        events.append(contentsOf: drawCards(
            companionCards,
            for: .companion,
            actor: actor,
            abilityName: triggerAbilityName(
                triggers.companionCardsEveryOtherTurn > 0
                    ? "companionCardsEveryOtherTurn" : "companionCardsPerTurn",
                for: actor,
                fallback: "Companion's Collar",
                in: context,
            ),
            in: &context,
        ))
        return events
    }

    private static func purifyingAuraIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.isPlayerTurn(every: 2, startingAt: 1), triggers.purifyingAura else { return [] }
        let abilityName = triggerAbilityName(
            "purifyingAura",
            for: actor,
            fallback: "Purifying Aura",
            in: context,
        )
        var events: [ActionEvent] = []
        for (_, target) in livingPartyMembers(in: context) {
            events.append(contentsOf: performRandomCleanses(
                source: actor,
                target: target.combatant,
                count: 1,
                abilityName: abilityName,
                in: &context,
            ))
        }
        return events
    }

    private static func applyDamageRamp(
        for actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        for (keyword, perRound, cap) in [
            (Keyword.burn, triggers.burnDamageRampPerRound, triggers.burnDamageRampCap),
            (Keyword.bleed, triggers.bleedDamageRampPerRound, triggers.bleedDamageRampCap),
        ] {
            guard perRound > 0 else { continue }
            context.roster.mutateRuntime(for: actor) { runtime in
                let current: Int = runtime.talents.battle.keywordDamageRamp[keyword, default: 0]
                var ramp: [Keyword: Int] = runtime.talents.battle.keywordDamageRamp
                ramp[keyword] = cap > 0 ? min(current + perRound, cap) : current + perRound
                runtime.talents.battle.keywordDamageRamp = ramp
            }
        }
    }

    private static func startOfTurnCombatBonuses(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        // Freeze and stun share the same every-N-turns cadence against the
        // enemy; only their interval/amount/keyword differ. The stun-attached
        // team block fires whenever the stun damage fired, even if that
        // damage defeated the enemy.
        var firedStunDamage = false
        for (interval, amount, keyword) in [
            (
                triggers.everyNTurnsFreezeAllEnemiesInterval,
                triggers.everyNTurnsFreezeAllEnemiesAmount,
                Keyword.freeze,
            ),
            (
                triggers.everyNTurnsStunBuildupInterval,
                triggers.everyNTurnsStunBuildupAmount,
                Keyword.stun,
            ),
        ] {
            guard interval > 0,
                  context.turnCount > 0,
                  context.isPlayerTurn(every: interval),
                  context.roster.enemy.isAlive
            else { continue }
            events.append(contentsOf: context.resolveDamage(DamageRequest(
                amount: amount,
                target: context.roster.enemy.combatant,
                keyword: keyword,
                sourceActorID: actor.id,
                options: .reaction(),
            )).events)
            if keyword == .stun {
                firedStunDamage = true
            }
        }
        if firedStunDamage, triggers.everyNTurnsTeamBlockAmount > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                events.append(contentsOf: emitBlock(
                    "everyNTurnsTeamBlockAmount", "Quaking Carapace",
                    amount: triggers.everyNTurnsTeamBlockAmount,
                    to: member.combatant, source: actor, in: &context,
                ))
            }
        }
        events.append(contentsOf: turnZeroBonuses(actor: actor, triggers: triggers, in: &context))
        return events
    }

    private static func turnZeroBonuses(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.turnCount == 0 else { return [] }
        var events: [ActionEvent] = []
        if triggers.startBattleBonusMana > 0 {
            events.append(contentsOf: emitMana(
                "startBattleBonusMana", "Dragon Spark",
                amount: triggers.startBattleBonusMana, to: actor, in: &context,
            ))
        }
        if triggers.startBattleBlock > 0 {
            events.append(contentsOf: emitBlock(
                "startBattleBlock", "Watchful Eye",
                amount: triggers.startBattleBlock, to: actor, source: actor, in: &context,
            ))
        }
        if triggers.startBattleThorns > 0 {
            events.append(contentsOf: heroTalentThorns(
                to: actor, source: actor, amount: triggers.startBattleThorns,
                name: triggerAbilityName("startBattleThorns", for: actor, fallback: "Thornwrought", in: context),
                in: &context,
            ))
        }
        if triggers.startBattleBonusGold > 0 {
            events.append(contentsOf: emitGold(
                "startBattleBonusGold", "Deep Pockets",
                amount: triggers.startBattleBonusGold, to: actor, in: &context,
            ))
        }
        if triggers.dodgeFirstAttackEachCombat {
            context.prependEffect(.evadeNextHit, to: actor, remainingTurns: 0)
        }
        return events
    }
}
