import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func turnBlock(
        for combatant: Combatant,
        in context: inout BattleState,
    ) {
        guard context.roster.health(for: combatant) > 0 else { return }
        let profile = context.modifiers(for: combatant.id)

        if profile.triggers.blockPerTurn > 0 {
            emitBlock(.blockPerTurn, "Trait", amount: profile.triggers.blockPerTurn, to: combatant, source: combatant, in: &context)
        }
        if profile.triggers.blockWhileGoldAmount > 0, profile.triggers.blockWhileGoldThreshold > 0,
           context.gold >= profile.triggers.blockWhileGoldThreshold {
            emitBlock(
                .blockWhileGoldAmount, "Golden Guard",
                amount: profile.triggers.blockWhileGoldAmount, to: combatant, source: combatant, in: &context,
            )
        }
    }

    static func atPlayerTurnStart(in context: inout BattleState) async {
        resetTurnCadenceState(in: &context)
        startHeroTalentTurn(in: &context)
        guard !context.isBattleOver else { return }
        // Preserve only due repeats; all other cadence state stays live in the roster.
        let dueBlessings = livingPartyMembers(in: context).map { (owner: $0.0, blessing: $0.1.talents.timed.lingeringBlessing) }
        for (owner, dueBlessing) in dueBlessings {
            guard var blessing = dueBlessing,
                  context.roster.combatant(for: blessing.sourceActorID) != nil else { continue }
            blessing.turnsRemaining -= 1
            context.roster.mutateRuntime(for: context.roster[owner].combatant) {
                $0.talents.timed.lingeringBlessing = blessing.turnsRemaining > 0 ? blessing : nil
            }
        }
        if context.turnCount > 0 {
            await BattleCardCombatEngine.restoreManaAtPlayerTurnStart(context: &context)
        }
        guard !context.isBattleOver else { return }
        await HealingEngine.resolveHealingEchoes(in: &context)
        guard !context.isBattleOver else { return }
        await cleanseTeamIfNeeded(in: &context)
        for (owner, blessing) in dueBlessings {
            guard !context.isBattleOver else { break }
            await startOfTurnCadence(for: owner, blessing: blessing, in: &context)
        }
    }

    private static func resetTurnCadenceState(in context: inout BattleState) {
        context.turnCadence.reset()
        for owner in BattleParticipant.allCases {
            context.roster.mutateRuntime(for: context.roster[owner].combatant) { runtime in
                runtime.talents.beginTurn(context.turnCount)
            }
        }
    }

    private static func cleanseTeamIfNeeded(in context: inout BattleState) async {
        for (owner, sourceRuntime) in livingPartyMembers(in: context) {
            guard !context.isBattleOver else { break }
            let count = context.modifiers(for: sourceRuntime.id).triggers.autoCleanseTeamPerTurn
            guard count > 0 else { continue }
            let abilityName = triggerAbilityName(
                .autoCleanseTeamPerTurn,
                for: sourceRuntime.combatant,
                fallback: "Trait",
                in: context,
            )
            for targetOwner in BattleParticipant.party {
                guard !context.isBattleOver, context.roster[owner].isAlive else { break }
                let target = context.roster[targetOwner]
                guard target.isAlive else { continue }
                await performRandomCleanses(
                    source: sourceRuntime.combatant,
                    target: target.combatant,
                    count: count,
                    abilityName: abilityName,
                    in: &context,
                )
            }
        }
    }

    private static func startOfTurnCadence(
        for owner: BattleParticipant,
        blessing: LingeringBlessing?,
        in context: inout BattleState,
    ) async {
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        let actor = context.roster[owner].combatant
        let triggers = context.modifiers(for: actor.id).triggers
        await startOfTurnRegen(blessing: blessing, actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        await forbiddenKnowledgeIfNeeded(for: owner, actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        companionCardsIfNeeded(for: owner, actor: actor, triggers: triggers, in: &context)
        await purifyingAuraIfNeeded(actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        await startOfTurnRecovery(actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        await startOfTurnMana(for: owner, actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        startOfTurnDrawCadence(for: owner, actor: actor, triggers: triggers, in: &context)
        await startOfTurnCombatBonuses(actor: actor, triggers: triggers, in: &context)
        guard !context.isBattleOver, context.roster[owner].isAlive else { return }
        applyDamageRamp(for: actor, triggers: triggers, in: &context)
    }

    private static func forbiddenKnowledgeIfNeeded(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.isPlayerTurn(every: 2, startingAt: 1), triggers.forbiddenKnowledge else { return }
        // Resolve the Health cost before drawing; ordinary Health-cost rules apply
        // with no hidden nonlethal floor. A defeated owner cannot continue.
        _ = await context.resolveDamage(DamageRequest(
            amount: 1,
            target: actor,
            keyword: nil,
            sourceActorID: actor.id,
            options: .healthCost,
        ))
        guard context.roster.health(for: actor) > 0 else { return }
        drawCards(
            1,
            for: owner,
            actor: actor,
            abilityName: triggerAbilityName(.forbiddenKnowledge, for: actor, fallback: "Forbidden Knowledge", in: context),
            in: &context,
        )
    }

    private static func companionCardsIfNeeded(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        if context.isPlayerTurn(every: 2, startingAt: 1), triggers.drawEveryOtherTurn > 0 {
            drawCards(
                triggers.drawEveryOtherTurn,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(.drawEveryOtherTurn, for: actor, fallback: "Tattered Pages", in: context),
                in: &context,
            )
        }
        let companionCards = SaturatedArithmetic.saturatingAdd(
            triggers.companionCardsPerTurn,
            context.isPlayerTurn(every: 2, startingAt: 1) ? triggers.companionCardsEveryOtherTurn : 0,
        )
        guard companionCards > 0 else { return }
        drawCards(
            companionCards,
            for: .companion,
            actor: actor,
            abilityName: triggerAbilityName(
                triggers.companionCardsEveryOtherTurn > 0
                    ? .companionCardsEveryOtherTurn : .companionCardsPerTurn,
                for: actor,
                fallback: "Companion's Collar",
                in: context,
            ),
            in: &context,
        )
    }

    private static func purifyingAuraIfNeeded(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.isPlayerTurn(every: 2, startingAt: 1), triggers.purifyingAura else { return }
        let abilityName = triggerAbilityName(
            .purifyingAura,
            for: actor,
            fallback: "Purifying Aura",
            in: context,
        )

        for (_, target) in livingPartyMembers(in: context) {
            guard !context.isBattleOver, context.health(of: actor) > 0 else { break }
            await performRandomCleanses(source: actor, target: target.combatant, count: 1, abilityName: abilityName, in: &context)
        }
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
                let increased = SaturatedArithmetic.saturatingAdd(current, perRound)
                runtime.talents.battle.keywordDamageRamp[keyword] = cap > 0 ? min(increased, cap) : increased
            }
        }
    }

    private static func startOfTurnCombatBonuses(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
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
            _ = await context.dealReactionDamage(amount, to: context.roster.enemy.combatant, keyword: keyword, sourceActorID: actor.id)
            if keyword == .stun {
                firedStunDamage = true
            }
        }
        if firedStunDamage, triggers.everyNTurnsTeamBlockAmount > 0 {
            for (_, member) in livingPartyMembers(in: context) {
                emitBlock(
                    .everyNTurnsTeamBlockAmount, "Quaking Carapace",
                    amount: triggers.everyNTurnsTeamBlockAmount,
                    to: member.combatant, source: actor, in: &context,
                )
            }
        }
        await turnZeroBonuses(actor: actor, triggers: triggers, in: &context)
    }

    private static func turnZeroBonuses(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard context.turnCount == 0 else { return }

        if triggers.startBattleBonusMana > 0 {
            await emitMana(.startBattleBonusMana, "Dragon Spark", amount: triggers.startBattleBonusMana, to: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.startBattleBlock > 0 {
            emitBlock(.startBattleBlock, "Watchful Eye", amount: triggers.startBattleBlock, to: actor, source: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.startBattleThorns > 0 {
            heroTalentThorns(
                to: actor, source: actor, amount: triggers.startBattleThorns,
                name: triggerAbilityName(.startBattleThorns, for: actor, fallback: "Thornwrought", in: context),
                in: &context,
            )
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.startBattleBonusGold > 0 {
            await emitGold(.startBattleBonusGold, "Deep Pockets", amount: triggers.startBattleBonusGold, to: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.dodgeFirstAttackEachCombat {
            context.insertEffect(.evadeNextHit, to: actor, remainingTurns: 0, at: 0)
        }
    }

    private static func startOfTurnRegen(
        blessing: LingeringBlessing?,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }

        if triggers.goldPerTurn > 0 {
            await emitGold(.goldPerTurn, "Merchant's Favor", amount: triggers.goldPerTurn, to: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.healthPerTurn > 0, context.isPlayerTurn(every: 2, startingAt: 1) {
            let target = BattleActionContext(actor: actor, in: context).target(.lowestHealthAlly, in: context)
            await emitHeal(.healthPerTurn, "Grove's Favor", amount: triggers.healthPerTurn, to: target, source: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if let blessing,
           let source = context.roster.combatant(for: blessing.sourceActorID) {
            let amount = blessing.amount
            var request = HealRequest(
                amount: amount,
                target: actor,
                sourceActorID: source.id,
                origin: .periodic, logAs: .instantHeal(
                    source: .init(source),
                    abilityName: "Lingering Blessing",
                    keyword: .health,
                ),
            )
            request.amountBasis = .resolved
            request.suppressTalentReactions = true
            _ = await HealingEngine.resolveHeal(request, in: &context)
        }
    }

    private static func startOfTurnRecovery(
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.goldEveryNTurnsInterval > 0,
           context.turnCount > 0,
           context.isPlayerTurn(every: triggers.goldEveryNTurnsInterval) {
            await emitGold(.goldEveryNTurnsAmount, "Dig for Treasure", amount: triggers.goldEveryNTurnsAmount, to: actor, in: &context)
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.healthRegenFirstTurnsDuration > 0,
           context.turnCount < triggers.healthRegenFirstTurnsDuration {
            await emitHeal(
                .healthRegenFirstTurnsAmount, "Sprite Touch",
                amount: triggers.healthRegenFirstTurnsAmount, to: actor, source: actor, in: &context,
            )
        }
        guard !context.isBattleOver, context.health(of: actor) > 0 else { return }
        if triggers.healthRegenAboveHalfHealth > 0,
           context.roster.maxHealth(for: actor) > 0,
           context.roster.isAboveHalfHealth(for: actor) {
            await emitHeal(
                .healthRegenAboveHalfHealth, "Safe Perch",
                amount: triggers.healthRegenAboveHalfHealth, to: actor, source: actor, in: &context,
            )
        }
    }

    private static func startOfTurnMana(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) async {
        if triggers.startTurnFullManaDrawCards > 0,
           let runtime = context.roster.runtime(for: actor),
           runtime.maxMana > 0,
           runtime.currentMana >= runtime.maxMana {
            drawCards(
                triggers.startTurnFullManaDrawCards,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    .startTurnFullManaDrawCards,
                    for: actor,
                    fallback: "Arcane Surge",
                    in: context,
                ),
                in: &context,
            )
        }
        if triggers.bonusManaOnTurns.contains(context.playerTurnNumber) {
            await emitMana(.bonusManaOnTurns, "Aetherial Surge", amount: 1, to: actor, in: &context)
        }
    }

    private static func startOfTurnDrawCadence(
        for owner: BattleParticipant,
        actor: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        if triggers.extraCardDrawWhileEnemyBleeding, context.roster.enemy.isAlive,
           context.roster.hasAffliction(.bleed, on: context.enemy) {
            drawCards(
                1,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    .extraCardDrawWhileEnemyBleeding,
                    for: actor,
                    fallback: "Frenzied Tail",
                    in: context,
                ),
                in: &context,
            )
        }
        if triggers.extraCardDrawBelowEnemyHealthPercent > 0, context.roster.enemy.isAlive,
           context.roster.maxHealth(for: context.roster.enemy.combatant) > 0,
           Double(context.roster.health(for: context.roster.enemy.combatant))
           / Double(context.roster.maxHealth(for: context.roster.enemy.combatant))
           < triggers.extraCardDrawBelowEnemyHealthPercent {
            drawCards(
                1,
                for: owner,
                actor: actor,
                abilityName: triggerAbilityName(
                    .extraCardDrawBelowEnemyHealthPercent,
                    for: actor,
                    fallback: "Feral Frenzy",
                    in: context,
                ),
                in: &context,
            )
        }
    }
}
