import Foundation
import TrinketContent
import TrinketCore

/// Item-affix combat reactions that fire from shared hook sites.
package enum CombatReactionEngine {
    package static func afterBleedApplied(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.combatant(for: sourceActorID) != nil else { return [] }
        let profile = context.modifiers(for: sourceActorID)
        var events: [ActionEvent] = []

        if profile.triggers.onBleedApplyPoison > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.triggers.onBleedApplyPoison,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
        }

        if profile.triggers.onBleedDealBurnDamage > 0 {
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: profile.triggers.onBleedDealBurnDamage,
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
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard keyword == .burn else { return [] }
        let potency = context.modifiers(for: sourceActorID).triggers.onBurnApplyPoison
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
        in context: inout BattleState
    ) -> Int {
        guard let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword,
              let source = context.roster.combatant(for: sourceActorID)
        else { return 0 }

        let profile = context.modifiers(for: sourceActorID)
        let targetIsFrozen = context.roster.hasControlStatus(for: state.combatant, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: state.combatant, keyword: .stun)
        let targetIsBurning = context.roster.activeEffects(for: state.combatant).contains {
            if case .burn = $0.effect {
                return true
            }
            return false
        }
        var bonus = 0

        if damageKeyword == .freeze, targetIsBurning {
            bonus += profile.triggers.freezeDamageWhileBurningBonus
        }
        // Shatter is an aura from hero gear: the enemy takes extra damage from party hits while Frozen.
        if source.role != .enemy, targetIsFrozen {
            bonus += context.heroModifiers.triggers.damageWhileTargetFrozenBonus
        }
        // Dazed is an aura from hero gear: the enemy takes extra damage from party hits while Stunned.
        if source.role != .enemy, targetIsStunned {
            bonus += context.heroModifiers.triggers.damageWhileTargetStunnedBonus
        }
        if profile.triggers.damageBelowHealthPercentBonus > 0,
           profile.triggers.damageBelowHealthPercentKeyword == nil || profile.triggers.damageBelowHealthPercentKeyword == damageKeyword,
           profile.triggers.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: state.combatant) > 0 {
            let percent = Double(context.roster.health(for: state.combatant)) /
                Double(context.roster.maxHealth(for: state.combatant))
            if percent < profile.triggers.damageBelowHealthPercentThreshold {
                bonus += profile.triggers.damageBelowHealthPercentBonus
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

    static func afterDodge(by combatant: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: combatant.id)
        var events: [ActionEvent] = []

        if profile.triggers.damageAfterDodgeBonus > 0 {
            context.roster.mutateRuntime(for: combatant) { runtime in
                runtime.pendingDamageAfterDodge += profile.triggers.damageAfterDodgeBonus
            }
        }

        if profile.triggers.dodgeGoldFlat > 0 {
            let granted = context.goldGranted(for: profile.triggers.dodgeGoldFlat, sourceActorID: combatant.id)
            context.addGold(profile.triggers.dodgeGoldFlat, sourceActorID: combatant.id)
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: combatant.name,
                abilityName: "Payday",
                target: combatant,
                amount: granted,
                keyword: .gold
            ))
        }

        if profile.triggers.dodgeBlockFlat > 0 {
            events.append(contentsOf: applyBlock(
                amount: profile.triggers.dodgeBlockFlat,
                to: combatant,
                source: combatant,
                abilityName: "Untouchable",
                in: &context
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

        return applyBlock(
            amount: profile.triggers.blockBrokenBlockFlat,
            to: target,
            source: target,
            abilityName: "Cascading",
            in: &context
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
                abilityName: "Branding",
                in: &context
            ))
        }

        if context.roster.health(for: enemy) > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: hero,
                abilityName: "Disrupting",
                count: profile.triggers.enemyStunnedPurgeCount,
                purgeAll: profile.triggers.enemyStunnedPurgeAll,
                in: &context
            ))
        }
        return events
    }

    static func afterSpendMana(by actor: Combatant, in context: inout BattleState) -> [ActionEvent] {
        let profile = context.modifiers(for: actor.id)
        var events: [ActionEvent] = []

        if profile.triggers.spendManaBlockFlat > 0 {
            events.append(contentsOf: applyBlock(
                amount: profile.triggers.spendManaBlockFlat,
                to: actor,
                source: actor,
                abilityName: "Aetherward",
                in: &context
            ))
        }

        let randomDoT = profile.triggers.spendManaRandomDoTFlat
        if randomDoT > 0, context.roster.enemy.isAlive {
            let enemy = context.roster.enemy.combatant
            if Bool.random(using: &context.rng) {
                events.append(contentsOf: context.applyDecayingDoT(
                    keyword: .burn,
                    potency: randomDoT,
                    to: enemy,
                    sourceActorID: actor.id,
                    dealImmediateDamage: true
                ))
            } else {
                events.append(contentsOf: context.resolveDamage(
                    DamageRequest(
                        amount: randomDoT,
                        target: enemy,
                        keyword: .freeze,
                        sourceActorID: actor.id,
                        options: DamageOptions(
                            applyStatBonus: false,
                            applyItemBonus: true,
                            applyDodge: false,
                            isRetaliation: true
                        )
                    )
                ).events)
            }
        }

        return events
    }

    static func afterStunDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.stunDamageBlockFlat
        guard amount > 0 else { return [] }
        return applyBlock(
            amount: amount,
            to: source,
            source: source,
            abilityName: context.modifiers(for: source.id).traitDisplayName ?? "Oathbound",
            in: &context
        )
    }

    static func afterBurnDamageDealt(
        to _: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: source.id).triggers.burnDamageHealFlat
        guard amount > 0 else { return [] }
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: source,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: context.modifiers(for: source.id).traitDisplayName ?? "Bloodfire",
                    keyword: .health,
                    displayAmount: amount
                )
            ),
            in: &context
        ).events
    }

    static func afterHolyDamageDealt(
        to enemy: Combatant,
        source: Combatant,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: source.id)
        var events: [ActionEvent] = []

        if profile.triggers.holyDamageBlockFlat > 0 {
            events.append(contentsOf: applyBlock(
                amount: profile.triggers.holyDamageBlockFlat,
                to: source,
                source: source,
                abilityName: "Sanctum",
                in: &context
            ))
        }

        if profile.triggers.holyDamageCleanseCount > 0 {
            var effects = context.roster.activeEffects(for: source)
            for _ in 0 ..< profile.triggers.holyDamageCleanseCount {
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

        if profile.triggers.holyDamageHealFlat > 0 {
            events.append(contentsOf: HealingEngine.resolveHeal(
                HealRequest(
                    amount: profile.triggers.holyDamageHealFlat,
                    target: source,
                    sourceActorID: source.id,
                    logAs: .instantHeal(
                        actorName: source.name,
                        abilityName: "Beacon",
                        keyword: .health,
                        displayAmount: profile.triggers.holyDamageHealFlat
                    )
                ),
                in: &context
            ).events)
        }

        if profile.triggers.holyDamagePurgeCount > 0 {
            events.append(contentsOf: applyPurge(
                to: enemy,
                source: source,
                abilityName: "Nullifying",
                count: profile.triggers.holyDamagePurgeCount,
                purgeAll: false,
                in: &context
            ))
        }

        return events
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleState
    ) -> [ActionEvent] {
        let percent = context.heroModifiers.triggers.companionLeechSharePercent
        guard restored > 0,
              percent > 0,
              context.roster.companion.isAlive
        else { return [] }
        let share = max(1, CombatRounding.scaled(restored, multiplier: percent))
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
                    abilityName: "Second Wind",
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
        var events: [ActionEvent] = []

        if purgeAll {
            guard EffectRemoval.removeBuffs(from: &enemyEffects, keyword: nil) else {
                return []
            }
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .purgeApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: .purge
            ))
        } else {
            for _ in 0 ..< count {
                guard let removedKeyword = EffectRemoval.removeRandomBuff(
                    from: &enemyEffects,
                    using: &context.rng
                ) else { break }
                events.append(context.nextEvent(
                    kind: .effect,
                    effectKind: .purgeApplied,
                    actorName: source.name,
                    abilityName: abilityName,
                    target: target,
                    amount: 0,
                    keyword: removedKeyword
                ))
            }
        }

        context.roster.setActiveEffects(enemyEffects, for: target)
        return events
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
        in context: inout BattleState
    ) -> [ActionEvent] {
        let adjusted = context.adjustedOutgoingEffect(
            .shield(.block, amount),
            sourceID: source.id
        )
        guard case let .shield(keyword, buffer) = adjusted else { return [] }
        let applied = DefensePoolEngine.add(
            buffer, pool: .block, to: target, keyword: keyword, sourceActorID: source.id, in: &context
        )
        return [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: keyword
        )]
    }
}
