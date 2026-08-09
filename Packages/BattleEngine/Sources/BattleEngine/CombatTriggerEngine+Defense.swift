import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func afterDodge(by combatant: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        var events: [ActionEvent] = []

        if profile.triggers.damageAfterDodgeBonus > 0 {
            context.roster.mutateRuntime(for: combatant) { runtime in
                runtime.pendingDamageAfterDodge += profile.triggers.damageAfterDodgeBonus
            }
        }

        if profile.triggers.dodgeGoldFlat > 0 {
            events.append(context.grantGoldEvent(
                profile.triggers.dodgeGoldFlat,
                to: combatant,
                abilityName: affixName(.payday)
            ))
        }

        if profile.triggers.dodgeBlockFlat > 0 {
            events.append(contentsOf: context.applyBlock(
                profile.triggers.dodgeBlockFlat,
                to: combatant,
                source: combatant,
                abilityName: affixName(.untouchable)
            ))
        }

        events.append(contentsOf: applySidestepHeal(for: combatant, profile: profile, in: &context))
        events.append(contentsOf: applyWhiplashStun(for: combatant, profile: profile, in: &context))

        if profile.triggers.dodgeApplyPoison > 0, context.roster.enemy.isAlive {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.triggers.dodgeApplyPoison,
                to: context.roster.enemy.combatant,
                sourceActorID: combatant.id,
                dealImmediateDamage: true
            ))
        }

        return events
    }

    static func afterBlockBroken(
        on target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.triggers.blockBrokenBlockFlat > 0 else { return [] }

        return context.applyBlock(
            profile.triggers.blockBrokenBlockFlat,
            to: target,
            source: target,
            abilityName: affixName(.cascading)
        )
    }

    static func afterEnemyStunned(in context: inout BattleState) -> [ActionEvent] {
        let profile = context.heroModifiers
        let shouldReact = profile.triggers.stunDealPhysicalFlat > 0
            || profile.triggers.enemyStunnedApplyMarked
            || profile.triggers.enemyStunnedPurgeCount > 0
            || profile.triggers.enemyStunnedPurgeAll
        guard shouldReact, context.roster.hero.isAlive else { return [] }

        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events = DoTDamage.resolveTurnDamage(
            basePotency: profile.triggers.stunDealPhysicalFlat,
            keyword: .physical,
            target: enemy,
            sourceActorID: hero.id,
            in: &context
        ).events

        if profile.triggers.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: hero.id,
                actorName: hero.name,
                abilityName: affixName(.branding),
                in: &context
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: hero,
                abilityName: affixName(.disrupting),
                count: profile.triggers.enemyStunnedPurgeCount,
                purgeAll: profile.triggers.enemyStunnedPurgeAll,
                in: &context
            ))
        }
        return events
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.triggers.onceBelowHealthPercentThreshold > 0,
              profile.triggers.onceBelowHealthPercentHeal > 0,
              context.roster.maxHealth(for: target) > 0,
              let runtime = context.roster.runtime(for: target),
              !runtime.hasTriggeredSecondWind
        else { return [] }

        // Death's Door owns lethal hits; Second Wind must not preempt it.
        let deathsDoorOwnsLethalHit = DeathsDoorEngine.applies(to: target)
            && context.roster.health(for: target) == 0
            && (!context.roster.hasConsumedDeathsDoor(for: target)
                || DeathsDoorEngine.hasLethalProtection(for: target, in: context))
        if deathsDoorOwnsLethalHit {
            return []
        }

        let percent = Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target))
        guard percent < profile.triggers.onceBelowHealthPercentThreshold else { return [] }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSecondWind = true }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.onceBelowHealthPercentHeal,
                target: target,
                sourceActorID: target.id,
                logAs: .instantHeal(
                    actorName: target.name,
                    abilityName: affixName(.secondWind),
                    keyword: .health,
                    displayAmount: profile.triggers.onceBelowHealthPercentHeal
                )
            ),
            in: &context
        ).events
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
                effect: .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
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

    private static func applySidestepHeal(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeHealFlat > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.triggers.dodgeHealFlat,
                target: combatant,
                sourceActorID: combatant.id,
                logAs: .instantHeal(
                    actorName: combatant.name,
                    abilityName: affixName(.sidestep),
                    keyword: .health,
                    displayAmount: profile.triggers.dodgeHealFlat
                )
            ),
            in: &context
        ).events
    }

    private static func applyWhiplashStun(
        for combatant: Combatant,
        profile: CombatModifierProfile,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard profile.triggers.dodgeDealStunFlat > 0, context.roster.enemy.isAlive else { return [] }
        // Avoid nesting a full damage pipeline inside DodgeGate (stack overflow in
        // long balance sims). Apply authored Stun damage as a direct health hit.
        let enemy = context.roster.enemy.combatant
        let amount = profile.triggers.dodgeDealStunFlat
        let lost = context.roster.runtime(for: enemy).map { runtime -> Int in
            var copy = runtime
            let dealt = copy.takeRawDamage(amount)
            context.roster.update(copy)
            return dealt
        } ?? 0
        guard lost > 0 else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: nil,
            actorName: combatant.name,
            abilityName: affixName(.whiplash),
            target: enemy,
            amount: lost,
            keyword: .stun
        )]
    }
}
