import Foundation
import TrinketContent
import TrinketCore

package extension HealingEngine {
    static func grantsLeech(
        to actor: CombatantRuntime,
        keyword damageKeyword: Keyword?,
        criticalAttack: Bool,
        attackHit: Bool,
        in context: BattleState,
    ) -> Bool {
        let profile = context.modifiers(for: actor.id)
        let triggers = profile.triggers
        if attackHit, triggers.borrowedLife, context.roster.isDeathsDoorActive(for: actor.combatant) {
            return true
        }
        switch damageKeyword {
        case .freeze:
            return triggers.freezeDamageLeech
        case .poison:
            return triggers.poisonDamageLeech || criticalAttack && triggers.poisonCriticalHasLeech
        case .burn:
            return triggers.burnDamageLeech
                || triggers.undyingEmber && context.roster.isDeathsDoorActive(for: actor.combatant)
        case .bleed:
            return triggers.bleedDamageLeech || criticalAttack && triggers.bleedCriticalHasLeech
                || attackHit && actor.currentHealth > 0 && actor.maxHealth > 0
                && Double(actor.currentHealth) / Double(actor.maxHealth) < triggers.bleedAttackLeechBelowHealthThreshold
        case .physical:
            return attackHit && actor.currentHealth > 0 && actor.currentHealth * 2 < actor.maxHealth
                && triggers.physicalAttackLeechBelowHalfHealth
        default:
            return false
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity - leech resolution is one atomic pipeline
    static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        target: Combatant? = nil,
        blockedAmount: Int = 0,
        abilityHasLeech: Bool = false,
        criticalAttack: Bool = false,
        attackHit: Bool = false,
        damageKeyword: Keyword? = nil,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard context.resolution.depth(.leechOverflowGold) == 0 else { return .empty }
        guard let actor = context.roster.combatant(for: sourceActorID),
              context.roster.health(for: actor.combatant) > 0
        else { return .empty }
        if actor.role == .enemy, let target,
           context.modifiers(for: target.id).triggers.enemyCannotLeechFromTarget {
            return .empty
        }
        let actorCombatant = actor.combatant

        let profile = context.modifiers(for: sourceActorID)
        var baseDamage = damage
        if profile.triggers.leechOnBlockDamage, blockedAmount > 0 {
            baseDamage += blockedAmount
        }
        guard baseDamage > 0 else { return .empty }

        var leechPct = 0.0
        if abilityHasLeech {
            leechPct = Effect.abilityLeechPercent
        }
        let keywordGrantsLeech = grantsLeech(
            to: actor, keyword: damageKeyword, criticalAttack: criticalAttack,
            attackHit: attackHit, in: context,
        )
        if leechPct == 0, keywordGrantsLeech {
            leechPct = Effect.abilityLeechPercent
        }
        if attackHit {
            leechPct = max(leechPct, profile.triggers.attackLeechPercent)
        }
        let typedChance: Double = switch damageKeyword {
        case .poison: profile.triggers.poisonDamageLeechChancePercent
        case .freeze: profile.triggers.freezeDamageLeechChancePercent
        default: 0
        }
        if leechPct == 0,
           BattleChance.succeeds(probability: min(1, profile.triggers.leechChancePercent + typedChance), using: &context.rng) {
            leechPct = Effect.abilityLeechPercent
        }
        if leechPct == 0, attackHit, actor.role == .hero, context.roster.companion.isAlive,
           context.companionModifiers.triggers.allyAttackLeechChancePercent > 0,
           context.claimTalentAbility("Pack Bloodlust", actorID: sourceActorID),
           BattleChance.succeeds(
               probability: context.companionModifiers.triggers.allyAttackLeechChancePercent,
               using: &context.rng,
           ) {
            leechPct = Effect.abilityLeechPercent
        }
        guard leechPct > 0 else { return .empty }
        leechPct += profile.leechGainedBonus

        if let target, profile.triggers.leechPercentVsLowHealthEnemies > 0,
           context.roster.maxHealth(for: target) > 0,
           Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target)) < 0.5 {
            leechPct += profile.triggers.leechPercentVsLowHealthEnemies
        }

        var restored = CombatRounding.scaled(baseDamage, multiplier: leechPct)
        restored += profile.leechHealingBonus
        if let target, profile.triggers.leechBonusHealVsLowHealthEnemies > 0,
           context.roster.maxHealth(for: target) > 0,
           Double(context.roster.health(for: target)) / Double(context.roster.maxHealth(for: target)) < 0.5 {
            restored += profile.triggers.leechBonusHealVsLowHealthEnemies
        }
        if let target, profile.triggers.leechBonusHealVsStunned > 0,
           context.roster.hasControlStatus(for: target, keyword: .stun) {
            restored += profile.triggers.leechBonusHealVsStunned
        }
        restored = CombatRounding.scaled(restored, multiplier: 1 + profile.leechHealingPercent)
        if let target, profile.triggers.leechHealingVsAfflictedMultiplier > 1 {
            let afflicted = context.roster.hasAffliction(.poison, on: target) || context.roster.hasAffliction(.bleed, on: target)
            if afflicted {
                restored = CombatRounding.scaled(restored, multiplier: profile.triggers.leechHealingVsAfflictedMultiplier)
            }
        }
        if let target, context.roster.hasAffliction(.bleed, on: target),
           profile.triggers.leechHealingVsBleedingMultiplier > 1 {
            restored = CombatRounding.scaled(
                restored, multiplier: profile.triggers.leechHealingVsBleedingMultiplier,
            )
        }
        if let target, context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target) {
            restored = CombatRounding.scaled(
                restored, multiplier: profile.triggers.leechHealingVsLowEnemyHealthMultiplier,
            )
        }
        if let target, context.roster.hasAffliction(.poison, on: target) {
            restored = CombatRounding.scaled(
                restored, multiplier: profile.triggers.leechHealingVsPoisonedMultiplier,
            )
        }
        if context.roster.runtime(for: actorCombatant)?.currentMana == 0,
           profile.triggers.darkRecoveryMultiplier > 1 {
            restored = CombatRounding.scaled(restored, multiplier: profile.triggers.darkRecoveryMultiplier)
        }
        guard restored > 0 else { return .empty }

        let preHealth = context.roster.health(for: actorCombatant)
        let maxHealth = context.roster.maxHealth(for: actorCombatant)
        var healing = await resolveHealing(
            HealRequest(
                amount: restored,
                target: actorCombatant,
                sourceActorID: sourceActorID,
                origin: .leech, logAs: .silent,
            ),
            in: &context,
        )
        if profile.triggers.excessLeechHealthToGold, healing.allocation.remaining > 0 {
            await healing.events.append(contentsOf: context.grantGoldEvent(
                healing.allocation.remaining, to: actorCombatant, abilityName: "Flawless Bounty",
                isLeechOverflow: true,
            ))
        }
        guard healing.didLeech else { return healing.combatOutcome }
        let actualRestored = healing.directRestoration
        var events = healing.events
        if actualRestored > 0, profile.triggers.leechBlockChancePercent > 0,
           BattleChance.succeeds(probability: profile.triggers.leechBlockChancePercent, using: &context.rng) {
            events.append(contentsOf: context.applyBlock(
                actualRestored,
                to: actorCombatant,
                source: actorCombatant,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    "leechBlockChancePercent", for: actorCombatant, fallback: "Bloodward", in: context,
                ),
                amountBasis: .resolved,
            ))
        }
        if actualRestored > 0, profile.triggers.leechThornsWithoutThorns > 0,
           !context.roster.activeEffects(for: actorCombatant).contains(where: {
               if case let .thorns(stacks) = $0.effect {
                   return stacks > 0
               }
               return false
           }),
           context.insertEffect(
               .thorns(profile.triggers.leechThornsWithoutThorns),
               to: actorCombatant, sourceID: actorCombatant.id, remainingTurns: 0,
               replacing: { $0.kind == .thorns },
           ) {
            events.append(context.nextEvent(
                kind: .effect, effectKind: .thornsApplied,
                actorName: actorCombatant.name,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    "leechThornsWithoutThorns", for: actorCombatant, fallback: "Bloodroot", in: context,
                ),
                target: actorCombatant, amount: profile.triggers.leechThornsWithoutThorns, keyword: .thorns,
            ))
        }
        if actualRestored > 0, preHealth * 2 < maxHealth,
           profile.triggers.leechStunBelowHalfHealth > 0,
           let target, target.role == .enemy, context.roster.health(for: target) > 0 {
            var operation = DamageOperation.reaction()
            operation.suppressLeech = true
            let stun = await context.resolveDamage(DamageRequest(
                amount: profile.triggers.leechStunBelowHalfHealth,
                target: target, keyword: .stun,
                sourceActorID: actorCombatant.id, options: operation,
            ))
            events.append(contentsOf: stun.events)
            if stun.healthLost > 0 {
                events.append(context.nextEvent(
                    kind: .abilityDamage, actorName: actorCombatant.name,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        "leechStunBelowHalfHealth", for: actorCombatant, fallback: "Heartshock", in: context,
                    ),
                    target: target, amount: stun.healthLost, keyword: .stun,
                ))
            }
        }
        if actualRestored > 0, preHealth < maxHealth,
           context.roster.health(for: actorCombatant) >= maxHealth,
           profile.triggers.leechToFullNextAttackBonus > 0 {
            context.roster.mutateRuntime(for: actorCombatant) {
                $0.talents.pending.attackBonusOnFullHealth = max(
                    $0.talents.pending.attackBonusOnFullHealth,
                    profile.triggers.leechToFullNextAttackBonus,
                )
            }
        }
        if actualRestored > 0, preHealth * 2 < maxHealth,
           profile.triggers.leechBlockBelowHalf {
            events.append(contentsOf: context.applyBlock(
                actualRestored,
                to: actorCombatant,
                source: actorCombatant,
                abilityName: "Soul Ward",
                amountBasis: .resolved,
            ))
        }
        if actualRestored > 0 {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: actorCombatant,
                amount: actualRestored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil,
                isCritical: healing.isCritical,
            ))
        }
        if actorCombatant.role != .enemy {
            await events.append(contentsOf: Self.shareLeechWithAlly(
                restored: actualRestored,
                source: actorCombatant,
                in: &context,
            ))
        }
        if actorCombatant.role == .companion, context.roster.hero.isAlive,
           profile.triggers.leechSharesToHeroPercent > 0 {
            let share = CombatRounding.scaled(
                actualRestored,
                multiplier: min(1, max(0, profile.triggers.leechSharesToHeroPercent)),
            )
            if share > 0 {
                var request = HealRequest(amount: share, target: context.roster.hero.combatant, sourceActorID: sourceActorID)
                request.amountBasis = .resolved
                await events.append(contentsOf: Self.resolveHeal(request, in: &context).events)
            }
        }
        if actorCombatant.role == .companion, context.roster.hero.isAlive,
           actualRestored > 0, profile.triggers.firstLeechRestorationShareAlly,
           context.claimHeroTalent("Soul Sharing", actorID: actorCombatant.id) {
            var request = HealRequest(
                amount: actualRestored,
                target: context.roster.hero.combatant,
                sourceActorID: sourceActorID,
            )
            request.amountBasis = .resolved
            await events.append(contentsOf: Self.resolveHeal(request, in: &context).events)
        }
        if actorCombatant.role == .companion, context.roster.hero.isAlive,
           profile.triggers.onCompanionLeechRestoreHeroMana > 0 {
            await events.append(contentsOf: context.restoreManaEmitting(
                profile.triggers.onCompanionLeechRestoreHeroMana,
                to: context.roster.hero.combatant,
                abilityName: "Vitality Infusion",
            ))
        }
        await events.append(contentsOf: CombatTriggerEngine.afterLeech(by: actorCombatant, target: target, in: &context))
        healing.events = events
        return healing.combatOutcome
    }

    static func shareLeechWithAlly(
        restored: Int,
        source: Combatant,
        in context: inout BattleState,
    ) async -> [ActionEvent] {
        // Symbiosis follows its wearer; companion-only talent shares keep their
        // separate rules above. Resolved shares never fund another Leech share.
        let ally = source.role == .hero ? context.roster.companion : context.roster.hero
        let percent = min(max(context.modifiers(for: source.id).triggers.companionLeechSharePercent, 0), 1)
        guard restored > 0,
              percent > 0,
              ally.isAlive
        else { return [] }
        let share = CombatRounding.scaled(restored, multiplier: percent)
        guard share > 0 else { return [] }
        var request = HealRequest(
            amount: share, target: ally.combatant, sourceActorID: source.id,
            logAs: .instantHeal(
                actorName: source.name,
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    "companionLeechSharePercent", for: source,
                    fallback: "Symbiosis", in: context,
                ),
                keyword: .health,
            ),
        )
        request.amountBasis = .resolved
        return await resolveHeal(request, in: &context).events
    }
}
