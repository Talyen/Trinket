import TrinketContent
import TrinketCore

// MARK: - Block gained, broken, and defense

package extension CombatTriggerEngine {
    static func afterBlockGained(
        _ amount: Int,
        by actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard amount > 0 else { return [] }
        let triggers = context.modifiers(for: actor.id).triggers
        var events = applyBlockThorns(amount: amount, triggers: triggers, actor: actor, in: &context)
        events.append(contentsOf: shareCompanionBlockToHero(
            amount: amount,
            triggers: triggers,
            actor: actor,
            in: &context,
        ))
        return events
    }

    static func applyBlockThorns(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        abilityKey: String = "blockGainThornsPercent",
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let percent = abilityKey == "blockGainThornsPercent"
            ? triggers.blockGainThornsPercent
            : triggers.retainedBlockGainThornsPercent
        let gained = CombatRounding.scaled(amount, multiplier: percent)
        guard gained > 0 else { return [] }
        let effects = context.roster.activeEffects(for: actor)
        let existing = effects.reduce(0) { total, active in
            if case let .thorns(stacks) = active.effect {
                return total + stacks
            }
            return total
        }
        let total = existing + gained
        guard context.insertEffect(
            .thorns(total), to: actor, sourceID: actor.id, remainingTurns: 0,
            replacing: { $0.kind == .thorns },
        ) else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: actor.name,
            abilityName: triggerAbilityName(
                abilityKey,
                for: actor,
                fallback: "Thorns",
                in: context,
            ),
            target: actor,
            amount: total,
            keyword: .thorns,
        )]
    }

    private static func shareCompanionBlockToHero(
        amount: Int,
        triggers: CombatTraitTriggers,
        actor: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard actor.role == .companion,
              triggers.companionBlockSharesToHeroPercent > 0,
              context.roster.hero.isAlive
        else { return [] }
        let share = CombatRounding.scaled(
            amount,
            multiplier: min(1, max(0, triggers.companionBlockSharesToHeroPercent)),
        )
        guard share > 0 else { return [] }
        guard context.claimHeroTalent(.shieldBond, actorID: actor.id) else { return [] }
        return context.applyBlock(
            share,
            to: context.roster.hero.combatant,
            source: actor,
            abilityName: triggerAbilityName(
                "companionBlockSharesToHeroPercent",
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
    ) async -> [ActionEvent] {
        guard power > 0,
              let attackerID,
              let attacker = context.roster.combatant(for: attackerID),
              attacker.isAlive,
              let runtime = context.roster.runtime(for: target),
              !runtime.talents.turn.triggeredBlockBreak
        else { return [] }
        context.roster.mutateRuntime(for: target) { $0.talents.turn.triggeredBlockBreak = true }

        var events: [ActionEvent] = []
        for keyword in [Keyword.holy, .stun] where context.roster.health(for: attacker.combatant) > 0 {
            let outcome = await context.resolveDamage(
                DamageRequest(
                    amount: power,
                    target: attacker.combatant,
                    keyword: keyword,
                    sourceActorID: target.id,
                    options: .reaction(),
                ),
            )
            events.append(contentsOf: outcome.events)
            if keyword == .holy, outcome.healthLost > 0 {
                await events.append(contentsOf: afterHolyDamageDealt(
                    to: attacker.combatant,
                    source: target,
                    in: &context,
                ))
            }
        }
        let healTarget = BattleActionContext(actor: target, in: context).target(.lowestHealthAlly, in: context)
        await events.append(contentsOf: emitHeal(
            "blockBrokenSaintfallPower", "Saintfall",
            amount: power, to: healTarget, source: target, in: &context,
        ))
        return events
    }

    // MARK: - Block broken and defense

    static func afterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events: [ActionEvent] = []
        if profile.triggers.blockBreakNextPhysicalBonus > 0, target.role != .enemy {
            context.roster.mutateRuntime(for: target) {
                $0.talents.pending.nextPhysicalDamageBonus = max(
                    $0.talents.pending.nextPhysicalDamageBonus,
                    profile.triggers.blockBreakNextPhysicalBonus,
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
            events.append(contentsOf: context.applyBlock(
                profile.triggers.blockBreakAllyBlockFlat,
                to: context.roster.hero.combatant,
                source: target,
                abilityName: "Shield Relay",
            ))
        }
        if target.role == .companion, profile.triggers.blockBreakStealGoldFlat > 0,
           context.roster.enemy.isAlive {
            await events.append(contentsOf: context.grantGoldEvent(
                profile.triggers.blockBreakStealGoldFlat,
                to: target, abilityName: "Trophy Scales", isTheft: true,
            ))
        }
        if profile.triggers.blockBrokenBlockFlat > 0 {
            events.append(contentsOf: emitBlock(
                "blockBrokenBlockFlat", "Cascading",
                amount: profile.triggers.blockBrokenBlockFlat, to: target, source: target, in: &context,
            ))
        }
        if profile.triggers.blockBrokenThornsFlat > 0 {
            await events.append(contentsOf: heroTalentThorns(
                to: target, source: target, amount: profile.triggers.blockBrokenThornsFlat,
                name: triggerAbilityName("blockBrokenThornsFlat", for: target, fallback: "Briarward", in: context),
                in: &context,
            ))
        }

        await events.append(contentsOf: saintfallAfterBlockBroken(
            on: target,
            attackerID: attackerID,
            power: profile.triggers.blockBrokenSaintfallPower,
            in: &context,
        ))
        return events
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

    static func afterEnemyStunned(sourceActorID: String?, in context: inout BattleState) async -> [ActionEvent] {
        // Pure read: hoisted so the three source-gated blocks below share one fetch.
        let triggers = sourceActorID.map { context.modifiers(for: $0).triggers }
        if let sourceActorID, let triggers, context.roster.enemy.isAlive {
            if triggers.stunnedEnemyLoseAllBlock {
                DefensePoolEngine.set(0, on: context.roster.enemy.combatant, in: &context)
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
        var events: [ActionEvent] = []
        for (_, member) in livingPartyMembers(in: context) {
            await events.append(contentsOf: afterEnemyStunnedReactions(for: member, sourceActorID: sourceActorID, in: &context))
        }
        return events
    }

    private static func afterEnemyStunnedReactions(
        for member: CombatantRuntime,
        sourceActorID: String?,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let profile = context.modifiers(for: member.id)
        let triggers = profile.triggers
        let shouldReact = triggers.stunDealPhysicalFlat > 0
            || triggers.enemyStunnedApplyMarked
            || triggers.enemyStunnedPurgeCount > 0
            || triggers.enemyStunnedPurgeAll
            || triggers.stunPurgeDealHolyPerEffect > 0
        guard shouldReact else { return [] }

        let actor = member.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events: [ActionEvent] = []
        if triggers.stunDealPhysicalFlat > 0 {
            await events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: triggers.stunDealPhysicalFlat,
                    target: enemy,
                    keyword: .physical,
                    sourceActorID: actor.id,
                    options: .reaction(),
                ),
            ).events)
        }

        if triggers.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: actor.id,
                actorName: actor.name,
                abilityName: triggerAbilityName("enemyStunnedApplyMarked", for: actor, fallback: "Branding", in: context),
                in: &context,
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            if triggers.stunPurgeDealHolyPerEffect > 0, actor.id == sourceActorID {
                await events.append(contentsOf: wardbreakerStunPurge(
                    perEffectHolyDamage: triggers.stunPurgeDealHolyPerEffect,
                    actor: actor,
                    enemy: enemy,
                    in: &context,
                ))
            } else {
                await events.append(contentsOf: applyPurge(
                    to: enemy,
                    source: actor,
                    abilityName: triggerAbilityName(
                        triggers.enemyStunnedPurgeAll ? "enemyStunnedPurgeAll" : "enemyStunnedPurgeCount",
                        for: actor,
                        fallback: "Disrupting",
                        in: context,
                    ),
                    count: triggers.enemyStunnedPurgeCount,
                    purgeAll: triggers.enemyStunnedPurgeAll,
                    in: &context,
                ))
            }
        }
        return events
    }

    private static func wardbreakerStunPurge(
        perEffectHolyDamage: Int,
        actor: Combatant,
        enemy: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let purge = await EffectRemovalOperation.resolvePurge(
            .all(nil),
            source: actor,
            target: enemy,
            abilityName: triggerAbilityName("stunPurgeDealHolyPerEffect", for: actor, fallback: "Disrupting", in: context),
            in: &context,
        )
        var events = purge.events
        if !purge.removed.isEmpty, context.roster.health(for: enemy) > 0 {
            await events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: perEffectHolyDamage * purge.removed.count,
                    target: enemy,
                    keyword: .holy,
                    sourceActorID: actor.id,
                    options: .reaction(),
                ),
            ).events)
        }
        return events
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events = await afterSurvivingHealthLoss(target: target, in: &context)
        let belowHalfThreshold = profile.triggers.onceBelowHealthPercentThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < profile.triggers.onceBelowHealthPercentThreshold
        if profile.triggers.onceBelowHealthPercentStunAllEnemies,
           belowHalfThreshold,
           context.roster.enemy.isAlive,
           context.claimBattleGuard(.seismicRoar, actorID: target.id) {
            let threshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            await events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                threshold,
                keyword: .stun,
                to: context.roster.enemy.combatant,
                sourceActorID: target.id,
                applyFightPacing: false,
                in: &context,
            ))
        }
        guard profile.triggers.onceBelowHealthPercentThreshold > 0,
              profile.triggers.onceBelowHealthPercentHeal > 0,
              context.roster.maxHealth(for: target) > 0,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredSecondWind
        else { return events }

        let deathsDoorOwnsLethalHit = DeathsDoorEngine.applies(to: target)
            && context.roster.health(for: target) == 0
            && (!context.roster.hasConsumedDeathsDoor(for: target)
                || DeathsDoorEngine.hasLethalProtection(for: target, in: context))
        if deathsDoorOwnsLethalHit {
            return events
        }

        let percent = Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
        guard percent < profile.triggers.onceBelowHealthPercentThreshold else { return events }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSecondWind = true }
        await events.append(contentsOf: emitHeal(
            "onceBelowHealthPercentHeal", "Second Wind",
            amount: profile.triggers.onceBelowHealthPercentHeal, to: target, source: target, in: &context,
        ))
        return events
    }

    /// Living-owner rewards also run after lethal protection restores Health.
    /// Second Wind and Seismic Roar retain their pre-protection checkpoint.
    static func afterSurvivingHealthLoss(
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard context.roster.health(for: target) > 0 else { return [] }
        var events = drawAfterHealthLoss(by: target, in: &context)
        preparePantherRedline(afterHealthLoss: target, in: &context)
        await events.append(contentsOf: vitalInfusionAfterHealthDrop(target: target, in: &context))
        if target.id == context.roster.hero.id, context.roster.hero.isAlive,
           context.roster.companion.isAlive,
           context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target),
           context.companionModifiers.triggers.allyFirstBelowHalfBlock > 0,
           context.claimHeroTalent(.grizzlyGuard, actorID: context.roster.companion.id, battle: true) {
            events.append(contentsOf: context.applyBlock(
                context.companionModifiers.triggers.allyFirstBelowHalfBlock,
                to: target,
                source: context.roster.companion.combatant,
                abilityName: "Grizzly Guard",
            ))
        }
        return events
    }

    private static func vitalInfusionAfterHealthDrop(
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        let amount = context.modifiers(for: target.id).triggers.firstBelowHalfHealthHeal
        guard amount > 0,
              context.roster.health(for: target) > 0,
              context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target),
              context.resolution.claim(.heroTalent(.vitalInfusion), actorID: target.id, cadence: .battle)
        else { return [] }
        return await context.healEmitting(amount: amount, target: target, source: target, abilityName: "Vital Infusion")
    }

    static func applyPurge(
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        count: Int,
        purgeAll: Bool,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        await EffectRemovalOperation.resolvePurge(
            purgeAll ? .all(nil) : .randomBuffs(count), source: source, target: target,
            abilityName: abilityName, in: &context,
        ).events
    }

    static func protectPurgedEffects(
        _ removed: [ActiveEffect], source: Combatant, target: Combatant, in context: inout BattleState,
    ) {
        guard context.modifiers(for: source.id).triggers.interdict, context.roster.health(for: source) > 0 else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.turn.purgedEffectProtection.formUnion(removed.map(\.effect.kind)) }
    }

    static func preventsPurgedEffect(_ effect: Effect, on target: Combatant, in context: BattleState) -> Bool {
        effect.isRemovableBuff && context.roster.runtime(for: target)?.talents.turn.purgedEffectProtection.contains(effect.kind) == true
    }

    static func crownfallDamage(
        removedCount: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        guard removedCount > 0,
              source.role != .enemy,
              target.role == .enemy,
              hasLivingPartyTrigger(\.crownfall, in: context)
        else { return [] }
        return await context.resolveDamage(DamageRequest(
            amount: removedCount * 3,
            target: target,
            keyword: .holy,
            sourceActorID: source.id,
            options: .reaction(),
        )).events
    }

    private static func applyMarked(
        to target: Combatant,
        sourceActorID: String,
        actorName: String,
        abilityName: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let markedEffect = Effect.marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration)
        guard !context.interceptDebuff(markedEffect, on: target) else { return [] }
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
        effects.append(
            ActiveEffect(
                id: context.consumeNextEffectID(),
                effect: markedEffect,
                remainingTurns: Effect.standardMarkedDuration,
                sourceActorID: sourceActorID,
            ),
        )
        context.roster.setActiveEffects(effects, for: target)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .markedApplied,
            actorName: actorName,
            abilityName: abilityName,
            target: target,
            amount: Effect.standardMarkedBonus,
            keyword: .physical,
        )]
    }
}
