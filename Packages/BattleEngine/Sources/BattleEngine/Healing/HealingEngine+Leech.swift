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
            return attackHit && triggers.poisonAttackLeech || criticalAttack && triggers.poisonCriticalHasLeech
        case .burn:
            return triggers.burnDamageLeech || attackHit && context.resolution.grantsBurnAttackLeech(to: actor.id)
                || triggers.undyingEmber && context.roster.isDeathsDoorActive(for: actor.combatant)
        case .bleed:
            return triggers.bleedDamageLeech || criticalAttack && triggers.bleedCriticalHasLeech
                || attackHit && actor.currentHealth > 0 && actor.maxHealth > 0
                && Double(actor.currentHealth) / Double(actor.maxHealth) < triggers.bleedAttackLeechBelowHealthThreshold
        case .physical:
            return attackHit && actor.currentHealth > 0 && actor.isBelowHalfHealth
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
        // swiftlint:disable:next closure_body_length - capture the complete atomic Leech pipeline including nested rewards
        let result = await context.collectingResult { context -> CombatOutcome in
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
                baseDamage = SaturatedArithmetic.saturatingAdd(baseDamage, blockedAmount)
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
               context.claimTalentAbility(.packBloodlust, actorID: sourceActorID),
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
               context.roster.isBelowHalfHealth(for: target) {
                leechPct += profile.triggers.leechPercentVsLowHealthEnemies
            }

            var restored = CombatRounding.scaled(baseDamage, multiplier: leechPct)
            restored = SaturatedArithmetic.saturatingAdd(restored, profile.leechHealingBonus)
            if let target, profile.triggers.leechBonusHealVsLowHealthEnemies > 0,
               context.roster.maxHealth(for: target) > 0,
               context.roster.isBelowHalfHealth(for: target) {
                restored = SaturatedArithmetic.saturatingAdd(restored, profile.triggers.leechBonusHealVsLowHealthEnemies)
            }
            if let target, profile.triggers.leechBonusHealVsStunned > 0,
               context.roster.hasControlStatus(for: target, keyword: .stun) {
                restored = SaturatedArithmetic.saturatingAdd(restored, profile.triggers.leechBonusHealVsStunned)
            }
            if let target, context.roster.isBelowHalfHealth(for: actorCombatant),
               context.roster.hasControlStatus(for: target, keyword: .stun) {
                restored = SaturatedArithmetic.saturatingAdd(restored, profile.triggers.leechHealVsStunnedBelowHalfFlat)
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
            if let target, context.roster.isBelowHalfHealth(for: target) {
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
            let healing = await resolveHealing(
                HealRequest(
                    amount: restored,
                    target: actorCombatant,
                    sourceActorID: sourceActorID,
                    origin: .leech, logAs: .silent,
                ),
                in: &context,
            )
            if profile.triggers.excessLeechHealthToGold, healing.allocation.remaining > 0 {
                _ = await context.grantGold(
                    healing.allocation.remaining, to: actorCombatant, abilityName: "Flawless Bounty",
                    isLeechOverflow: true,
                )
            }
            guard healing.didLeech else { return healing.combatOutcome }
            let actualRestored = healing.directRestoration
            let survivedRestoration = context.roster.health(for: actorCombatant) > 0

            if survivedRestoration, actualRestored > 0, profile.triggers.leechBlockChancePercent > 0,
               BattleChance.succeeds(probability: profile.triggers.leechBlockChancePercent, using: &context.rng) {
                context.applyBlockGain(
                    actualRestored,
                    to: actorCombatant,
                    source: actorCombatant,
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        .leechBlockChancePercent, for: actorCombatant, fallback: "Bloodward", in: context,
                    ),
                    amountBasis: .resolved,
                )
            }
            if survivedRestoration, actualRestored > 0, profile.triggers.leechThornsWithoutThorns > 0,
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
                context.nextEvent(
                    kind: .effect(.thornsApplied),
                    source: .init(actorCombatant),
                    abilityName: CombatTriggerEngine.triggerAbilityName(
                        .leechThornsWithoutThorns, for: actorCombatant, fallback: "Bloodroot", in: context,
                    ),
                    target: actorCombatant, amount: profile.triggers.leechThornsWithoutThorns, keyword: .thorns,
                )
            }
            if survivedRestoration, actualRestored > 0, preHealth < maxHealth,
               context.roster.health(for: actorCombatant) >= maxHealth,
               profile.triggers.leechToFullNextAttackBonus > 0 {
                let bonus = max(
                    context.roster.runtime(for: actorCombatant)?.talents.pending.attackBonusOnFullHealth?.value ?? 0,
                    profile.triggers.leechToFullNextAttackBonus,
                )
                context.prepareAttackBonus(bonus, \.attackBonusOnFullHealth, for: actorCombatant)
            }
            if survivedRestoration, actualRestored > 0, HealthThreshold.isBelowHalf(preHealth, maximum: maxHealth),
               profile.triggers.leechBlockBelowHalf {
                context.applyBlockGain(
                    actualRestored,
                    to: actorCombatant,
                    source: actorCombatant,
                    abilityName: "Soul Ward",
                    amountBasis: .resolved,
                )
            }
            if actualRestored > 0 {
                context.nextEvent(
                    kind: .effect(.leechHeal),
                    source: .init(actorCombatant),
                    abilityName: "Leech",
                    target: actorCombatant,
                    amount: actualRestored,
                    keyword: .leech,
                    appliedEffectSummaries: [],
                    isCritical: healing.isCritical,
                )
            }
            if actorCombatant.role != .enemy {
                await Self.shareLeechWithAlly(restored: actualRestored, source: actorCombatant, in: &context)
            }
            if actorCombatant.role == .companion, context.roster.health(for: actorCombatant) > 0, context.roster.hero.isAlive,
               profile.triggers.leechSharesToHeroPercent > 0 {
                let share = CombatRounding.scaled(
                    actualRestored,
                    multiplier: min(1, max(0, profile.triggers.leechSharesToHeroPercent)),
                )
                if share > 0 {
                    var request = HealRequest(amount: share, target: context.roster.hero.combatant, sourceActorID: sourceActorID)
                    request.amountBasis = .resolved
                    _ = await Self.resolveHeal(request, in: &context)
                }
            }
            if actorCombatant.role == .companion, context.roster.health(for: actorCombatant) > 0, context.roster.hero.isAlive,
               actualRestored > 0, profile.triggers.firstLeechRestorationShareAlly,
               context.claimHeroTalent(.soulSharing, actorID: actorCombatant.id) {
                var request = HealRequest(
                    amount: actualRestored,
                    target: context.roster.hero.combatant,
                    sourceActorID: sourceActorID,
                )
                request.amountBasis = .resolved
                _ = await Self.resolveHeal(request, in: &context)
            }
            if actorCombatant.role == .companion, context.roster.health(for: actorCombatant) > 0, context.roster.hero.isAlive,
               profile.triggers.onCompanionLeechRestoreHeroMana > 0 {
                await context.restoreManaEmitting(
                    profile.triggers.onCompanionLeechRestoreHeroMana,
                    to: context.roster.hero.combatant,
                    abilityName: "Vitality Infusion",
                )
            }
            await CombatTriggerEngine.afterLeech(by: actorCombatant, target: target, in: &context)
            return healing.combatOutcome
        }
        var outcome = result.value
        outcome.events = result.events
        return outcome
    }

    static func shareLeechWithAlly(
        restored: Int,
        source: Combatant,
        in context: inout BattleState,
    ) async {
        // Symbiosis follows its wearer; companion-only talent shares keep their
        // separate rules above. Resolved shares never fund another Leech share.
        let ally = source.role == .hero ? context.roster.companion : context.roster.hero
        let percent = min(max(context.modifiers(for: source.id).triggers.companionLeechSharePercent, 0), 1)
        guard context.roster.health(for: source) > 0, restored > 0,
              percent > 0,
              ally.isAlive
        else { return }
        let share = CombatRounding.scaled(restored, multiplier: percent)
        guard share > 0 else { return }
        var request = HealRequest(
            amount: share, target: ally.combatant, sourceActorID: source.id,
            logAs: .instantHeal(
                source: .init(source),
                abilityName: CombatTriggerEngine.triggerAbilityName(
                    .companionLeechSharePercent, for: source,
                    fallback: "Symbiosis", in: context,
                ),
                keyword: .health,
            ),
        )
        request.amountBasis = .resolved
        _ = await resolveHeal(request, in: &context)
    }
}
