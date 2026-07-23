import Foundation
import TrinketContent
import TrinketCore

/// Item-affix combat reactions that fire from shared hook sites.
package enum CombatReactionEngine {
    package static func afterBleedApplied(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard context.roster.combatant(for: sourceActorID) != nil else { return [] }
        let profile = context.modifiers(for: sourceActorID)
        var events: [ActionEvent] = []

        if profile.onBleedApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.onBleedApplyPoison,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
        }

        if profile.onBleedDealBurnDamage > 0 {
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: profile.onBleedDealBurnDamage,
                keyword: .burn,
                target: target,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        return events
    }

    package static func afterDecayingDoTApplied(
        keyword: Keyword,
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard keyword == .burn else { return [] }
        let potency = context.modifiers(for: sourceActorID).onBurnApplyPoison
        guard potency > 0 else { return [] }
        return context.applyDecayingDoT(
            keyword: .poison,
            potency: potency,
            to: target,
            sourceActorID: sourceActorID,
            dealImmediateDamage: true,
            suppressAffixReactions: true
        )
    }
}

package extension CombatReactionEngine {
    static func affixDamageBonus(
        for state: DamageResolutionState,
        in context: inout BattleEngineContext
    ) -> Int {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 0 }

        let profile = context.modifiers(for: sourceActorID)
        let targetIsFrozen = context.roster.hasPendingActionSkip(for: state.combatant, keyword: .freeze)
        let targetIsStunned = context.roster.hasPendingActionSkip(for: state.combatant, keyword: .stun)
        let targetIsBurning = context.roster.activeEffects(for: state.combatant).contains {
            if case .burn = $0.effect {
                return true
            }
            return false
        }
        var bonus = 0

        if damageKeyword == .freeze, targetIsBurning {
            bonus += profile.freezeDamageWhileBurningBonus
        }
        // Shatter is an aura from hero gear: the enemy takes extra damage from party hits while Frozen.
        if source.role != .enemy, targetIsFrozen {
            bonus += context.heroModifiers.damageWhileTargetFrozenBonus
        }
        // Dazed is an aura from hero gear: the enemy takes extra damage from party hits while Stunned.
        if source.role != .enemy, targetIsStunned {
            bonus += context.heroModifiers.damageWhileTargetStunnedBonus
        }
        if profile.damageBelowHealthPercentBonus > 0,
           profile.damageBelowHealthPercentKeyword == nil || profile.damageBelowHealthPercentKeyword == damageKeyword,
           profile.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: state.combatant) > 0 {
            let percent = Double(context.roster.health(for: state.combatant)) /
                Double(context.roster.maxHealth(for: state.combatant))
            if percent < profile.damageBelowHealthPercentThreshold {
                bonus += profile.damageBelowHealthPercentBonus
            }
        }

        // Direct ability hits only — DoT ticks also run with applyItemBonus and
        // would otherwise spend the dodge bonus on end-of-round status damage.
        if state.qualifiesForAmbush,
           let runtime = context.roster.runtime(for: source.combatant),
           runtime.pendingDamageAfterDodge > 0 {
            bonus += runtime.pendingDamageAfterDodge
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageAfterDodge = 0 }
        }

        return bonus
    }

    static func afterDodge(by combatant: Combatant, in context: inout BattleEngineContext) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        var events: [ActionEvent] = []

        if profile.damageAfterDodgeBonus > 0 {
            context.roster.mutateRuntime(for: combatant) { runtime in
                runtime.pendingDamageAfterDodge += profile.damageAfterDodgeBonus
            }
        }

        if profile.dodgeGoldFlat > 0 {
            let bonus = context.modifiers(for: combatant.id).goldGainedBonus
            context.addGold(profile.dodgeGoldFlat, sourceActorID: combatant.id)
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: combatant.name,
                abilityName: "Payday",
                target: combatant,
                amount: profile.dodgeGoldFlat + bonus,
                keyword: .gold
            ))
        }

        if profile.dodgeBlockFlat > 0 {
            events.append(contentsOf: applyBlock(
                amount: profile.dodgeBlockFlat,
                to: combatant,
                source: combatant,
                abilityName: "Untouchable",
                in: &context
            ))
        }

        return events
    }

    static func afterBlockBroken(
        on target: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.blockBrokenBlockFlat > 0 else { return [] }

        return applyBlock(
            amount: profile.blockBrokenBlockFlat,
            to: target,
            source: target,
            abilityName: "Cascading",
            in: &context
        )
    }

    static func afterEnemyStunned(in context: inout BattleEngineContext) -> [ActionEvent] {
        let profile = context.heroModifiers
        guard profile.stunDealPhysicalFlat > 0 || profile.enemyStunnedApplyMarked,
              context.roster.hero.isAlive
        else { return [] }

        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        guard context.roster.health(for: enemy) > 0 else { return [] }

        var events = DoTDamage.resolveTurnDamage(
            basePotency: profile.stunDealPhysicalFlat,
            keyword: .physical,
            target: enemy,
            sourceActorID: hero.id,
            in: &context
        ).events

        if profile.enemyStunnedApplyMarked, context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyMarked(
                to: enemy,
                sourceActorID: hero.id,
                actorName: hero.name,
                abilityName: "Branding",
                in: &context
            ))
        }
        return events
    }

    static func afterSpendMana(by actor: Combatant, in context: inout BattleEngineContext) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).spendManaBlockFlat
        guard amount > 0 else { return [] }
        return applyBlock(
            amount: amount,
            to: actor,
            source: actor,
            abilityName: "Aetherward",
            in: &context
        )
    }

    static func afterHolyDamageDealt(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: source.id)
        var events: [ActionEvent] = []

        if profile.holyDamageBlockFlat > 0 {
            events.append(contentsOf: applyBlock(
                amount: profile.holyDamageBlockFlat,
                to: source,
                source: source,
                abilityName: "Sanctum",
                in: &context
            ))
        }

        if profile.holyDamageCleanseCount > 0 {
            var effects = context.roster.activeEffects(for: source)
            for _ in 0 ..< profile.holyDamageCleanseCount {
                guard let removedKeyword = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) else { break }
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .cleanseApplied,
                    actorName: source.name,
                    abilityName: "Absolving",
                    target: source,
                    amount: 0,
                    keyword: removedKeyword
                ))
            }
            context.roster.setActiveEffects(effects, for: source)
        }

        if profile.holyDamageHealFlat > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: profile.holyDamageHealFlat,
                    target: source,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: "Beacon",
                        keyword: .health,
                        displayAmount: profile.holyDamageHealFlat
                    )
                ),
                in: &context
            ).events)
        }

        if profile.holyDamagePurgeCount > 0 {
            var enemyEffects = context.roster.activeEffects(for: enemy)
            for _ in 0 ..< profile.holyDamagePurgeCount {
                guard let removedKeyword = EffectRemoval.removeRandomBuff(from: &enemyEffects, using: &context.rng) else { break }
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .purgeApplied,
                    actorName: source.name,
                    abilityName: "Nullifying",
                    target: enemy,
                    amount: 0,
                    keyword: removedKeyword
                ))
            }
            context.roster.setActiveEffects(enemyEffects, for: enemy)
        }

        return events
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let percent = context.heroModifiers.companionLeechSharePercent
        guard restored > 0,
              percent > 0,
              context.roster.companion.isAlive
        else { return [] }
        let share = max(1, Int(floor(Double(restored) * percent)))
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: share,
                target: context.roster.companion.combatant,
                sourceActorID: context.roster.hero.id,
                logAs: .instantHeal(
                    actorName: context.roster.hero.name,
                    abilityName: "Symbiosis",
                    keyword: .health,
                    displayAmount: share
                ),
                suppressTraitReactions: true
            ),
            in: &context
        ).events
    }

    static func afterHealthDropped(
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.onceBelowHealthPercentThreshold > 0,
              profile.onceBelowHealthPercentHeal > 0,
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
        guard percent < profile.onceBelowHealthPercentThreshold else { return [] }
        context.roster.mutateRuntime(for: target) { $0.hasTriggeredSecondWind = true }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: profile.onceBelowHealthPercentHeal,
                target: target,
                sourceActorID: target.id,
                logAs: .instantHeal(
                    actorName: target.name,
                    abilityName: "Second Wind",
                    keyword: .health,
                    displayAmount: profile.onceBelowHealthPercentHeal
                )
            ),
            in: &context
        ).events
    }

    private static func applyMarked(
        to target: Combatant,
        sourceActorID: String,
        actorName: String,
        abilityName: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .marked = $0.effect {
                return true
            }; return false
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

    static func applyBlock(
        amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityName: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let adjusted = context.adjustedOutgoingEffect(
            .shield(.block, amount),
            sourceID: source.id
        )
        guard case let .shield(keyword, buffer) = adjusted else { return [] }
        DefensePoolEngine.add(buffer, pool: .block, to: target, keyword: keyword, in: &context)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: buffer,
            keyword: keyword
        )]
    }
}
