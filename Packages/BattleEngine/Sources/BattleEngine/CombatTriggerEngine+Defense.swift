import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterBlockBroken(
        on target: Combatant,
        attackerID: String?,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events: [ActionEvent] = []
        if profile.triggers.blockBrokenBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.blockBrokenBlockFlat,
                to: target,
                source: target,
                abilityName: triggerAbilityName("blockBrokenBlockFlat", for: target, fallback: "Cascading", in: context)
            ))
        }

        events.append(contentsOf: saintfallAfterBlockBroken(
            on: target,
            attackerID: attackerID,
            power: profile.triggers.blockBrokenSaintfallPower,
            in: &context
        ))
        return events
    }

    static func afterEnemyStunned(in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for owner in [BattleParticipant.hero, .companion] {
            events.append(contentsOf: afterEnemyStunnedReactions(for: owner, in: &context))
        }
        return events
    }

    private static func afterEnemyStunnedReactions(
        for owner: BattleParticipant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let runtime = context.roster[owner]
        guard runtime.isAlive else { return [] }
        let profile = context.modifiers(for: runtime.id)
        let triggers = profile.triggers
        let shouldReact = triggers.stunDealPhysicalFlat > 0
            || triggers.enemyStunnedApplyMarked
            || triggers.enemyStunnedPurgeCount > 0
            || triggers.enemyStunnedPurgeAll
            || triggers.stunPurgeDealHolyPerEffect > 0
        guard shouldReact else { return [] }

        let actor = runtime.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events: [ActionEvent] = []
        if triggers.stunDealPhysicalFlat > 0 {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: triggers.stunDealPhysicalFlat,
                    target: enemy,
                    keyword: .physical,
                    sourceActorID: actor.id,
                    options: .flatReaction
                )
            ).events)
        }

        if triggers.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: actor.id,
                actorName: actor.name,
                abilityName: triggerAbilityName("enemyStunnedApplyMarked", for: actor, fallback: "Branding", in: context),
                in: &context
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            if triggers.stunPurgeDealHolyPerEffect > 0 {
                events.append(contentsOf: wardbreakerStunPurge(
                    perEffectHolyDamage: triggers.stunPurgeDealHolyPerEffect,
                    actor: actor,
                    enemy: enemy,
                    in: &context
                ))
            } else {
                events.append(contentsOf: applyPurge(
                    to: enemy,
                    source: actor,
                    abilityName: triggerAbilityName(
                        triggers.enemyStunnedPurgeAll ? "enemyStunnedPurgeAll" : "enemyStunnedPurgeCount",
                        for: actor,
                        fallback: "Disrupting",
                        in: context
                    ),
                    count: triggers.enemyStunnedPurgeCount,
                    purgeAll: triggers.enemyStunnedPurgeAll,
                    in: &context
                ))
            }
        }
        return events
    }

    private static func wardbreakerStunPurge(
        perEffectHolyDamage: Int,
        actor: Combatant,
        enemy: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let removableCount = context.roster.activeEffects(for: enemy)
            .filter(\.effect.isRemovableBuff)
            .count
        var events = applyPurge(
            to: enemy,
            source: actor,
            abilityName: triggerAbilityName("stunPurgeDealHolyPerEffect", for: actor, fallback: "Disrupting", in: context),
            count: 0,
            purgeAll: true,
            in: &context
        )
        if removableCount > 0, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: context.resolveDamage(
                DamageRequest(
                    amount: perEffectHolyDamage * removableCount,
                    target: enemy,
                    keyword: .holy,
                    sourceActorID: actor.id,
                    options: .flatReaction
                )
            ).events)
        }
        return events
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        var events = drawAfterHealthLoss(by: target, in: &context)
        let belowHalfThreshold = profile.triggers.onceBelowHealthPercentThreshold > 0
            && context.roster.maxHealth(for: target) > 0
            && Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
            < profile.triggers.onceBelowHealthPercentThreshold
        if profile.triggers.onceBelowHealthPercentStunAllEnemies,
           belowHalfThreshold,
           context.roster.enemy.isAlive,
           context.claimBattleGuard(.seismicRoar, actorID: target.id) {
            let threshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            events.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                threshold,
                keyword: .stun,
                to: context.roster.enemy.combatant,
                sourceActorID: target.id,
                applyFightPacing: false,
                in: &context
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
        events.append(contentsOf: context.healEmitting(
            amount: profile.triggers.onceBelowHealthPercentHeal,
            target: target,
            source: target,
            abilityName: triggerAbilityName("onceBelowHealthPercentHeal", for: target, fallback: "Second Wind", in: context)
        ))
        return events
    }

    static func applyPurge(
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        count: Int,
        purgeAll: Bool,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard purgeAll || count > 0 else { return [] }
        var enemyEffects = context.roster.activeEffects(for: target)
        let removedKeywords = EffectRemoval.removeBuffs(
            from: &enemyEffects,
            count: count,
            removeAll: purgeAll,
            using: &context.rng
        )
        guard !removedKeywords.isEmpty else { return [] }
        context.roster.setActiveEffects(enemyEffects, for: target)
        return removedKeywords.map { keyword in
            context.nextEvent(
                kind: .effect,
                effectKind: .purgeApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: keyword
            )
        }
    }

    private static func applyMarked(
        to target: Combatant,
        sourceActorID: String,
        actorName: String,
        abilityName: String,
        in context: inout BattleState
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
                sourceActorID: sourceActorID
            )
        )
        context.roster.setActiveEffects(effects, for: target)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .markedApplied,
            actorName: actorName,
            abilityName: abilityName,
            target: target,
            amount: Effect.standardMarkedBonus,
            keyword: .physical
        )]
    }
}
