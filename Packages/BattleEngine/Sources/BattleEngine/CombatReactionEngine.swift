import Foundation
import TrinketContent
import TrinketCore

/// Item-affix combat reactions that fire from shared hook sites.
package enum CombatReactionEngine {
    package static func refreshBleedOnReapplyIfNeeded(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> Bool {
        guard context.modifiers(for: sourceActorID).refreshBleedOnReapply else { return false }
        var effects = context.roster.activeEffects(for: target)
        let fullDuration = Effect.bleedDoTTickCount + context.modifiers(for: sourceActorID).bleedDurationBonus
        var didRefresh = false
        for index in effects.indices {
            guard case .bleed = effects[index].effect else { continue }
            effects[index].remainingTicks = fullDuration
            didRefresh = true
        }
        guard didRefresh else { return false }
        context.roster.setActiveEffects(effects, for: target)
        return true
    }

    package static func afterBleedApplied(
        to target: Combatant,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard let source = context.roster.combatant(for: sourceActorID) else { return [] }
        let profile = context.modifiers(for: sourceActorID)
        var events: [ActionEvent] = []

        var bleedApplyCount = 0
        context.roster.mutateRuntime(for: source.combatant) { runtime in
            runtime.bleedApplyCount += 1
            bleedApplyCount = runtime.bleedApplyCount
        }

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
            events.append(contentsOf: DoTDamage.resolveTick(
                basePotency: profile.onBleedDealBurnDamage,
                keyword: .burn,
                target: target,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        if profile.everyNthBleedApplyCount > 0,
           bleedApplyCount.isMultiple(of: profile.everyNthBleedApplyCount),
           profile.everyNthBleedApplyPoisonPotency > 0 {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: profile.everyNthBleedApplyPoisonPotency,
                to: target,
                sourceActorID: sourceActorID,
                dealImmediateDamage: true,
                suppressAffixReactions: true
            ))
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

    package static func afterBurnTick(
        target: Combatant,
        sourceActorID: String?,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)
        else { return [] }
        let profile = context.modifiers(for: sourceActorID)
        guard profile.everyNthBurnTickCount > 0,
              profile.everyNthBurnTickFreezeDamage > 0
        else { return [] }

        var burnTickCount = 0
        context.roster.mutateRuntime(for: source.combatant) { runtime in
            runtime.burnTickCount += 1
            burnTickCount = runtime.burnTickCount
        }
        guard burnTickCount.isMultiple(of: profile.everyNthBurnTickCount) else { return [] }

        return DoTDamage.resolveTick(
            basePotency: profile.everyNthBurnTickFreezeDamage,
            keyword: .freeze,
            target: target,
            sourceActorID: sourceActorID,
            in: &context
        ).events
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
        var bonus = 0

        if damageKeyword == .freeze, targetIsFrozen {
            bonus += profile.freezeDamageWhileFrozenBonus
        }
        // Brittle is an aura from hero gear: the enemy takes extra damage from party hits.
        if source.role != .enemy, targetIsFrozen {
            bonus += context.heroModifiers.damageWhileTargetFrozenBonus
        }
        if profile.damageBelowHealthPercentBonus > 0,
           profile.damageBelowHealthPercentKeyword == damageKeyword,
           profile.damageBelowHealthPercentThreshold > 0,
           context.roster.maxHealth(for: state.combatant) > 0 {
            let percent = Double(context.roster.health(for: state.combatant)) /
                Double(context.roster.maxHealth(for: state.combatant))
            if percent < profile.damageBelowHealthPercentThreshold {
                bonus += profile.damageBelowHealthPercentBonus
            }
        }

        if let runtime = context.roster.runtime(for: source.combatant),
           runtime.pendingDamageAfterDodge > 0 {
            bonus += runtime.pendingDamageAfterDodge
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDamageAfterDodge = 0 }
        }

        return bonus
    }

    static func applyHexmarkIfNeeded(
        to state: inout DamageResolutionState,
        in context: inout BattleEngineContext
    ) {
        let hero = context.roster.hero.combatant
        guard state.qualifiesForAmbush,
              state.amount > 0,
              state.sourceActorID == hero.id,
              context.heroModifiers.firstHitApplyMarked,
              let runtime = context.roster.runtime(for: hero),
              !runtime.hasTriggeredHexmark
        else { return }

        context.roster.mutateRuntime(for: hero) { $0.hasTriggeredHexmark = true }
        state.activeEffects.removeAll {
            if case .marked = $0.effect {
                return true
            }; return false
        }
        state.activeEffects.append(
            ActiveEffect(
                id: context.consumeNextEffectID(),
                effect: .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
                remainingTicks: Effect.standardMarkedDuration,
                sourceActorID: hero.id
            )
        )
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedApplied,
            actorName: hero.name,
            abilityName: "Hexmark",
            target: state.combatant,
            amount: Effect.standardMarkedBonus,
            keyword: .physical
        ))
    }

    static func afterDodge(by combatant: Combatant, in context: inout BattleEngineContext) {
        let bonus = context.modifiers(for: combatant.id).damageAfterDodgeBonus
        guard bonus > 0 else { return }
        context.roster.mutateRuntime(for: combatant) { runtime in
            runtime.pendingDamageAfterDodge += bonus
        }
    }

    static func afterBlockBroken(
        on target: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.blockBrokenArmorFlat > 0 else { return [] }

        let amount = profile.blockBrokenArmorFlat + profile.armorGainedBonus
        DefensePoolEngine.addArmor(amount, to: target, in: &context)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .mitigationApplied,
            actorName: target.name,
            abilityName: "Cascading",
            target: target,
            amount: amount,
            keyword: .armor
        )]
    }

    static func afterArmorGained(
        by target: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: target.id).armorGainedBlock
        guard amount > 0 else { return [] }
        return applyBlock(
            amount: amount,
            to: target,
            source: target,
            abilityName: "Undergird",
            in: &context
        )
    }

    static func afterBlockGained(
        by target: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let profile = context.modifiers(for: target.id)
        guard profile.blockGainedCleanseCount > 0,
              profile.blockGainedCleanseIntervalTicks > 0
        else { return [] }

        var effects = context.roster.activeEffects(for: target)
        guard effects.contains(where: \.effect.isRemovableDebuff) else { return [] }
        guard let runtime = context.roster.runtime(for: target) else { return [] }
        if let lastTick = runtime.lastAblutionTick,
           context.tickCount - lastTick < profile.blockGainedCleanseIntervalTicks {
            return []
        }

        var events: [ActionEvent] = []
        for _ in 0 ..< profile.blockGainedCleanseCount {
            guard let removedKeyword = EffectRemoval.removeRandomDebuff(from: &effects, using: &context.rng) else { break }
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: target.name,
                abilityName: "Ablution",
                target: target,
                amount: 0,
                keyword: removedKeyword
            ))
        }
        guard !events.isEmpty else { return [] }
        context.roster.setActiveEffects(effects, for: target)
        let tick = context.tickCount
        context.roster.mutateRuntime(for: target) { $0.lastAblutionTick = tick }
        return events
    }

    static func afterEnemyStunned(in context: inout BattleEngineContext) -> [ActionEvent] {
        let duration = context.heroModifiers.enemyStunnedHasteDurationTicks
        guard duration > 0, context.roster.hero.isAlive else { return [] }
        let hero = context.roster.hero.combatant
        context.appendEffect(.haste(duration), to: hero, sourceID: hero.id, remainingTicks: duration)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .hasteApplied,
            actorName: hero.name,
            abilityName: "Aftershock",
            target: hero,
            amount: duration,
            keyword: .physical
        )]
    }

    static func afterPetActed(in context: inout BattleEngineContext) -> [ActionEvent] {
        let profile = context.heroModifiers
        guard profile.petActLeechPercent > 0,
              profile.petActLeechDurationTicks > 0,
              context.roster.hero.isAlive
        else { return [] }

        let hero = context.roster.hero.combatant
        let adjusted = context.adjustedOutgoingEffect(
            .leech(.leech, profile.petActLeechPercent, profile.petActLeechDurationTicks),
            sourceID: hero.id
        )
        guard case let .leech(keyword, percent, duration) = adjusted else { return [] }
        var effects = context.roster.activeEffects(for: hero)
        effects.removeAll {
            if case .leech = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: hero)
        context.appendEffect(.leech(keyword, percent, duration), to: hero, sourceID: hero.id, remainingTicks: duration)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .leechApplied,
            actorName: hero.name,
            abilityName: "Packbond",
            target: hero,
            amount: Int(percent * 100),
            keyword: keyword
        )]
    }

    static func shareHeroHealWithPet(
        restored: Int,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let percent = context.heroModifiers.petHealSharePercent
        guard restored > 0,
              percent > 0,
              context.roster.pet.isAlive
        else { return [] }
        let share = max(1, Int(floor(Double(restored) * percent)))
        return HealingEngine.resolveHeal(
            HealRequest(
                amount: share,
                target: context.roster.pet.combatant,
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

    static func atStartOfAction(
        by actor: Combatant,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        let amount = context.modifiers(for: actor.id).blockPerActionWhileDeathsDoor
        guard amount > 0,
              context.roster.isDeathsDoorActive(for: actor),
              actor.role == .hero || actor.role == .pet
        else { return [] }
        return applyBlock(
            amount: amount,
            to: actor,
            source: actor,
            abilityName: "Deathgrip",
            in: &context
        )
    }

    private static func applyBlock(
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
        DefensePoolEngine.addBlock(buffer, to: target, keyword: keyword, in: &context)
        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: buffer,
            keyword: keyword
        )]
        events.append(contentsOf: afterBlockGained(by: target, in: &context))
        return events
    }
}
