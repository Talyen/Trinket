import TrinketContent
import TrinketCore

// MARK: - Block gained, broken, and defense

package extension CombatTriggerEngine {
    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState,
    ) {
        guard amount > 0 else { return }
        let triggers = context.modifiers(for: actor.id).triggers
        applyBlockThorns(amount: amount, triggers: triggers, actor: actor, in: &context)
        shareCompanionBlockToHero(amount: amount, triggers: triggers, actor: actor, in: &context)
    }

    static func applyBlockThorns(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        abilityKey: CombatTriggerField = .blockGainThornsPercent,
        in context: inout BattleState,
    ) {
        let percent = abilityKey == .blockGainThornsPercent
            ? triggers.blockGainThornsPercent
            : triggers.retainedBlockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard gained > 0 else { return }
        heroTalentThorns(
            to: actor, source: actor, amount: gained,
            name: triggerAbilityName(abilityKey, for: actor, fallback: "Thorns", in: context), in: &context,
        )
    }

    private static func shareCompanionBlockToHero(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) {
        guard actor.role == .companion,
              triggers.companionBlockSharesToHeroPercent > 0,
              context.roster.hero.isAlive
        else { return }
        let share = CombatRounding.scaled(
            amount,
            multiplier: min(1, max(0, triggers.companionBlockSharesToHeroPercent)),
        )
        guard share > 0 else { return }
        guard context.claimHeroTalent(.shieldBond, actorID: actor.id) else { return }
        context.applyBlockGain(
            share,
            to: context.roster.hero.combatant,
            source: actor,
            abilityName: triggerAbilityName(
                .companionBlockSharesToHeroPercent,
                for: actor,
                fallback: "Shield Bond",
                in: context,
            ),
            amountBasis: .resolved,
        )
    }

    static func saintfallAfterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        power: Int,
        in context: inout BattleState,
    ) async {
        guard power > 0,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID),
              attacker.isAlive,
              let runtime = context.roster.runtime(for: target),
              !runtime.talents.turn.triggeredBlockBreak
        else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.turn.triggeredBlockBreak = true }

        for keyword in [Keyword.holy, .stun] where context.roster.health(for: attacker.combatant) > 0 {
            guard context.roster.health(for: target) > 0 else { return }
            let outcome = await context.dealReactionDamage(power, to: attacker.combatant, keyword: keyword, sourceActorID: target.id)

            if keyword == .holy, outcome.healthLost > 0 {
                await afterHolyDamageDealt(to: attacker.combatant, source: target, in: &context)
            }
        }
        guard context.roster.health(for: target) > 0 else { return }
        let healTarget = BattleActionContext(actor: target, in: context).target(.lowestHealthAlly, in: context)
        await emitHeal(.blockBrokenSaintfallPower, "Saintfall", amount: power, to: healTarget, source: target, in: &context)
    }

    // MARK: - Block broken and defense

    static func afterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: target.id)

        if profile.triggers.blockBreakNextPhysicalBonus > 0, target.role != .enemy {
            let serial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: target) {
                $0.talents.pending.nextPhysicalDamageBonus = PreparedTalentBonus(
                    value: max($0.talents.pending.nextPhysicalDamageBonus?.value ?? 0, profile.triggers.blockBreakNextPhysicalBonus),
                    cardSerial: serial, actionID: actionID,
                )
            }
        }
        if profile.triggers.blockBreakNextHolyHitDouble {
            let serial = context.resolution.cardTalents?.playSerial
            context.roster.mutateRuntime(for: target) {
                $0.talents.pending.nextHolyHitDouble = PreparedTalentBonus(value: true, cardSerial: serial)
            }
        }
        prepareQuakingStunDouble(on: target, triggers: profile.triggers, in: &context)
        if target.role == .companion, context.roster.hero.isAlive,
           profile.triggers.blockBreakAllyBlockFlat > 0 {
            context.applyBlockGain(
                profile.triggers.blockBreakAllyBlockFlat,
                to: context.roster.hero.combatant,
                source: target,
                abilityName: "Shield Relay",
            )
        }
        if target.role == .companion, profile.triggers.blockBreakStealGoldFlat > 0,
           context.roster.enemy.isAlive {
            _ = await context.grantGold(
                profile.triggers.blockBreakStealGoldFlat,
                to: target, abilityName: "Trophy Scales", isTheft: true,
            )
        }
        if profile.triggers.blockBrokenBlockFlat > 0 {
            emitBlock(
                .blockBrokenBlockFlat, "Cascading",
                amount: profile.triggers.blockBrokenBlockFlat, to: target, source: target, in: &context,
            )
        }
        if profile.triggers.blockBrokenThornsFlat > 0 {
            heroTalentThorns(
                to: target, source: target, amount: profile.triggers.blockBrokenThornsFlat,
                name: triggerAbilityName(.blockBrokenThornsFlat, for: target, fallback: "Briarward", in: context),
                in: &context,
            )
        }

        await saintfallAfterBlockBroken(on: target, attackerID: attackerID, power: profile.triggers.blockBrokenSaintfallPower, in: &context)
    }

    private static func prepareQuakingStunDouble(
        on target: Combatant,
        triggers: CombatTraitTriggers,
        in context: inout BattleState,
    ) {
        guard triggers.firstBlockBreakNextStunDouble,
              context.claimHeroTalent(.quakingCarapace, actorID: target.id, battle: true) else { return }
        let serial = context.resolution.cardTalents?.playSerial
        context.roster.mutateRuntime(for: target) {
            $0.talents.pending.nextStunAttackDouble = PreparedTalentBonus(value: true, cardSerial: serial)
        }
    }

    static func afterEnemyStunned(sourceActorID: String?, in context: inout BattleState) async {
        // Pure read: hoisted so the three source-gated blocks below share one fetch.
        let triggers = sourceActorID.map { context.modifiers(for: $0).triggers }
        if let sourceActorID, let triggers, context.roster.enemy.isAlive {
            if triggers.stunnedEnemyLoseAllBlock {
                DefensePoolEngine.strip(
                    Int.max, from: context.roster.enemy.combatant,
                    source: context.eventSource(actorID: sourceActorID, fallback: context.roster.enemy.combatant),
                    abilityName: context.modifiers(for: sourceActorID).triggerAbilityName(
                        .stunnedEnemyLoseAllBlock,
                        fallback: "Sunder Shield",
                    ),
                    in: &context,
                )
            }
            if triggers.onStunNextAttackGuaranteedCritical,
               let source = context.roster.combatant(for: sourceActorID), source.isAlive {
                let serial = context.resolution.cardTalents?.playSerial
                let actionID = context.resolution.actionID
                context.roster.mutateRuntime(for: source.combatant) {
                    $0.talents.pending.nextStunPreparedCritical = PreparedTalentBonus(value: true, cardSerial: serial, actionID: actionID)
                }
            }
        }
        if let sourceActorID, let triggers,
           let source = context.roster.combatant(for: sourceActorID), source.isAlive,
           triggers.stunNextBlockGainMultiplier > 1 {
            let preparedCardSerial = context.resolution.cardTalents?.playSerial
            let actionID = context.resolution.actionID
            context.roster.mutateRuntime(for: source.combatant) {
                $0.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(
                    value: max($0.talents.pending.nextBlockGainMultiplier?.value ?? 1, triggers.stunNextBlockGainMultiplier),
                    cardSerial: preparedCardSerial,
                    actionID: actionID,
                )
            }
        }
        if let sourceActorID,
           sourceActorID == context.roster.hero.id || sourceActorID == context.roster.companion.id,
           context.roster.hero.isAlive,
           context.heroModifiers.triggers.shatterpoint,
           context.roster.hasAffliction(.bleed, on: context.roster.enemy.combatant) {
            context.roster.mutateRuntime(for: context.roster.enemy.combatant) {
                $0.talents.pending.doubleNextBleedDamage = true
            }
        }

        for (_, member) in livingPartyMembers(in: context) {
            await afterEnemyStunnedReactions(for: member, sourceActorID: sourceActorID, in: &context)
        }
    }

    private static func afterEnemyStunnedReactions(
        for member: CombatantRuntime,
        sourceActorID: String?,
        in context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: member.id)
        let triggers = profile.triggers
        let causedStun = member.id == sourceActorID
        let shouldReact = triggers.enemyStunnedApplyMarked
            || (causedStun && (triggers.stunDealPhysicalFlat > 0
                    || triggers.enemyStunnedPurgeCount > 0
                    || triggers.enemyStunnedPurgeAll
                    || triggers.stunPurgeDealHolyPerEffect > 0))
        guard shouldReact else { return }

        let actor = member.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: actor) > 0,
              context.roster.health(for: enemy) > 0 else { return }

        if causedStun, triggers.stunDealPhysicalFlat > 0 {
            _ = await context.dealReactionDamage(triggers.stunDealPhysicalFlat, to: enemy, keyword: .physical, sourceActorID: actor.id)
        }

        guard context.roster.health(for: actor) > 0,
              context.roster.health(for: enemy) > 0 else { return }
        if triggers.enemyStunnedApplyMarked {
            applyMarked(
                to: enemy,
                source: actor,
                abilityName: triggerAbilityName(.enemyStunnedApplyMarked, for: actor, fallback: "Branding", in: context),
                in: &context,
            )
        }

        if causedStun, context.roster.health(for: enemy) > 0 {
            if triggers.stunPurgeDealHolyPerEffect > 0 {
                await wardbreakerStunPurge(
                    perEffectHolyDamage: triggers.stunPurgeDealHolyPerEffect,
                    actor: actor,
                    enemy: enemy,
                    in: &context,
                )
            } else {
                await applyPurge(
                    to: enemy,
                    source: actor,
                    abilityName: triggerAbilityName(
                        triggers.enemyStunnedPurgeAll ? .enemyStunnedPurgeAll : .enemyStunnedPurgeCount,
                        for: actor,
                        fallback: "Disrupting",
                        in: context,
                    ),
                    count: triggers.enemyStunnedPurgeCount,
                    purgeAll: triggers.enemyStunnedPurgeAll,
                    in: &context,
                )
            }
        }
    }

    private static func wardbreakerStunPurge(
        perEffectHolyDamage: Int,
        actor: Combatant,
        enemy: Combatant,
        in context: inout BattleState,
    ) async {
        let purge = await EffectRemovalOperation.resolvePurge(
            .all(nil),
            source: actor,
            target: enemy,
            abilityName: triggerAbilityName(.stunPurgeDealHolyPerEffect, for: actor, fallback: "Disrupting", in: context),
            in: &context,
        )

        if !purge.removed.isEmpty,
           context.roster.health(for: actor) > 0,
           context.roster.health(for: enemy) > 0 {
            _ = await context.dealReactionDamage(
                SaturatedArithmetic.saturatingMul(perEffectHolyDamage, purge.removed.count), to: enemy, keyword: .holy,
                sourceActorID: actor.id,
            )
        }
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleState,
    ) async {
        let profile = context.modifiers(for: target.id)
        await afterSurvivingHealthLoss(target: target, in: &context)
        let belowHalfThreshold = profile.triggers.onceBelowHealthPercentThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < profile.triggers.onceBelowHealthPercentThreshold
        if profile.triggers.onceBelowHealthPercentStunAllEnemies,
           belowHalfThreshold,
           context.roster.enemy.isAlive,
           context.claimBattleGuard(.seismicRoar, actorID: target.id) {
            let threshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            await ControlMeterEngine.applyMeterCharge(
                threshold,
                keyword: .stun,
                to: context.roster.enemy.combatant,
                sourceActorID: target.id,
                applyFightPacing: false,
                in: &context,
            )
        }
        guard profile.triggers.onceBelowHealthPercentThreshold > 0,
              profile.triggers.onceBelowHealthPercentHeal > 0,
              context.roster.maxHealth(for: target) > 0,
              context.roster.health(for: target) > 0,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredSecondWind
        else { return }

        let deathsDoorOwnsLethalHit = DeathsDoorEngine.applies(to: target)
            && context.roster.health(for: target) == 0
            && (!context.roster.hasConsumedDeathsDoor(for: target)
                || DeathsDoorEngine.hasLethalProtection(for: target, in: context))
        if deathsDoorOwnsLethalHit {
            return
        }

        let percent = Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
        guard percent < profile.triggers.onceBelowHealthPercentThreshold else { return }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSecondWind = true }
        await emitHeal(
            .onceBelowHealthPercentHeal, "Second Wind",
            amount: profile.triggers.onceBelowHealthPercentHeal, to: target, source: target, in: &context,
        )
    }

    /// Living-owner rewards also run after lethal protection restores Health.
    /// Second Wind and Seismic Roar retain their pre-protection checkpoint.
    static func afterSurvivingHealthLoss(
        target: Combatant,
        in context: inout BattleState,
    ) async {
        guard context.roster.health(for: target) > 0 else { return }
        drawAfterHealthLoss(by: target, in: &context)
        preparePantherRedline(afterHealthLoss: target, in: &context)
        await vitalInfusionAfterHealthDrop(target: target, in: &context)
        if target.id == context.roster.hero.id, context.roster.hero.isAlive,
           context.roster.companion.isAlive,
           context.roster.isBelowHalfHealth(for: target),
           context.companionModifiers.triggers.allyFirstBelowHalfBlock > 0,
           context.claimHeroTalent(.grizzlyGuard, actorID: context.roster.companion.id, battle: true) {
            context.applyBlockGain(
                context.companionModifiers.triggers.allyFirstBelowHalfBlock,
                to: target,
                source: context.roster.companion.combatant,
                abilityName: "Grizzly Guard",
            )
        }
    }

    private static func vitalInfusionAfterHealthDrop(
        target: Combatant,
        in context: inout BattleState,
    ) async {
        let amount = context.modifiers(for: target.id).triggers.firstBelowHalfHealthHeal
        guard amount > 0,
              context.roster.health(for: target) > 0,
              context.roster.isBelowHalfHealth(for: target),
              context.resolution.claim(.heroTalent(.vitalInfusion), actorID: target.id, cadence: .battle)
        else { return }
        await context.healEmitting(amount: amount, target: target, source: target, abilityName: "Vital Infusion")
    }

    static func applyPurge(
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        count: Int,
        purgeAll: Bool,
        in context: inout BattleState,
    ) async {
        _ = await EffectRemovalOperation.resolvePurge(
            purgeAll ? .all(nil) : .randomBuffs(count), source: source, target: target,
            abilityName: abilityName, in: &context,
        )
    }

    static func protectPurgedEffects(
        _ removed: [ActiveEffect], source: Combatant, target: Combatant, in context: inout BattleState,
    ) {
        guard context.modifiers(for: source.id).triggers.interdict, context.roster.health(for: source) > 0 else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.turn.purgedEffectProtection.formUnion(removed.map(\.effect.kind)) }
    }

    static func preventsPurgedEffect(_ effect: Effect, on target: Combatant, in context: BattleState) -> Bool {
        if case .shield(.block, _) = effect,
           context.roster.runtime(for: target)?.talents.turn.blockGainPrevented == true {
            return true
        }
        return effect.isRemovableBuff && context.roster.runtime(for: target)?.talents.turn.purgedEffectProtection
            .contains(effect.kind) == true
    }

    static func crownfallDamage(
        removedCount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async {
        guard removedCount > 0,
              source.role != .enemy,
              target.role == .enemy,
              hasLivingPartyTrigger(\.crownfall, in: context)
        else { return }
        _ = await context.dealReactionDamage(removedCount * 3, to: target, keyword: .holy, sourceActorID: source.id)
    }

    private static func applyMarked(
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        in context: inout BattleState,
    ) {
        let markedEffect = Effect.marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration)
        guard context.insertEffect(
            markedEffect, to: target, sourceID: source.id, remainingTurns: Effect.standardMarkedDuration,
            replacing: { $0.kind == .marked },
        ) else { return }
        context.nextEvent(
            kind: .effect(.markedApplied),
            source: .init(source),
            abilityName: abilityName,
            target: target,
            amount: Effect.standardMarkedBonus,
            keyword: .physical,
        )
    }
}
