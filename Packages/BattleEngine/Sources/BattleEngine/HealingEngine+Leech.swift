import Foundation
import TrinketContent
import TrinketCore

package extension HealingEngine {
    // swiftlint:disable:next function_body_length cyclomatic_complexity - leech resolution is one atomic pipeline
    static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        target: Combatant? = nil,
        blockedAmount: Int = 0,
        abilityHasLeech: Bool = false,
        damageKeyword: Keyword? = nil,
        in context: inout BattleState,
    ) -> CombatOutcome {
        guard let actor = context.roster.combatant(for: sourceActorID),
              context.roster.health(for: actor.combatant) > 0
        else { return .empty }
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
        let keywordGrantsLeech = damageKeyword == .freeze && profile.triggers.freezeDamageLeech
            || damageKeyword == .poison && profile.triggers.poisonDamageLeech
            || damageKeyword == .burn && profile.triggers.burnDamageLeech
            || damageKeyword == .bleed && profile.triggers.bleedDamageLeech
            || damageKeyword == .physical && profile.triggers.borrowedLife
            && context.roster.isDeathsDoorActive(for: actorCombatant)
        if leechPct == 0, keywordGrantsLeech {
            leechPct = Effect.abilityLeechPercent
        }
        if leechPct == 0,
           BattleChance.succeeds(probability: profile.triggers.leechChancePercent, using: &context.rng) {
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
        if let target, profile.triggers.leechHealingVsAfflictedMultiplier > 1 {
            let afflicted = context.roster.activeEffects(for: target).contains {
                $0.effect.keyword == .poison || $0.effect.keyword == .bleed
            }
            if afflicted {
                restored = CombatRounding.scaled(restored, multiplier: profile.triggers.leechHealingVsAfflictedMultiplier)
            }
        }
        guard restored > 0 else { return .empty }

        var events: [ActionEvent] = []
        var actualRestored = 0
        var leechFlags = Set<CombatFlag>()
        if actorCombatant.role == .hero,
           context.roster.companion.isAlive,
           profile.triggers.leechOverhealTransfersToCompanion,
           context.roster.health(for: actorCombatant) >= context.roster.maxHealth(for: actorCombatant) {
            let healOutcome = resolveHeal(
                HealRequest(
                    amount: restored,
                    target: context.roster.companion.combatant,
                    sourceActorID: sourceActorID,
                    origin: .leech, logAs: .silent,
                ),
                in: &context,
            )
            guard healOutcome.healthRestored > 0 else { return healOutcome }
            actualRestored = healOutcome.healthRestored
            leechFlags = healOutcome.flags
            events.append(contentsOf: healOutcome.events)
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .leechHeal,
                actorName: actorCombatant.name,
                abilityName: "Leech",
                target: context.roster.companion.combatant,
                amount: actualRestored,
                keyword: .leech,
                appliedEffectSummaries: [],
                milestone: nil,
                isCritical: healOutcome.isCritical,
            ))
        } else {
            let healOutcome = resolveHeal(
                HealRequest(
                    amount: restored,
                    target: actorCombatant,
                    sourceActorID: sourceActorID,
                    origin: .leech, logAs: .silent,
                ),
                in: &context,
            )
            guard healOutcome.healthRestored > 0 else { return healOutcome }
            actualRestored = healOutcome.healthRestored
            leechFlags = healOutcome.flags
            events.append(contentsOf: healOutcome.events)
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
                isCritical: healOutcome.isCritical,
            ))
            if actorCombatant.id == context.roster.hero.id {
                events.append(contentsOf: Self.shareHeroLeechWithCompanion(
                    restored: actualRestored,
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
                    events.append(contentsOf: Self.resolveHeal(
                        HealRequest(amount: share, target: context.roster.hero.combatant, sourceActorID: sourceActorID),
                        in: &context,
                    ).events)
                }
            }
            if actorCombatant.role == .companion, context.roster.hero.isAlive,
               profile.triggers.onCompanionLeechRestoreHeroMana > 0 {
                events.append(contentsOf: context.restoreManaEmitting(
                    profile.triggers.onCompanionLeechRestoreHeroMana,
                    to: context.roster.hero.combatant,
                    abilityName: "Vitality Infusion",
                ))
            }
        }
        events.append(contentsOf: CombatTriggerEngine.afterLeech(by: actorCombatant, target: target, in: &context))
        var flags = leechFlags
        flags.insert(.leeched)
        return CombatOutcome(healthDelta: actualRestored, events: events, flags: flags)
    }

    static func shareHeroLeechWithCompanion(
        restored: Int,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let percent = min(max(context.heroModifiers.triggers.companionLeechSharePercent, 0), 1)
        guard restored > 0,
              percent > 0,
              context.roster.companion.isAlive
        else { return [] }
        let share = max(1, CombatRounding.scaled(restored, multiplier: percent))
        return context.healEmitting(
            amount: share,
            target: context.roster.companion.combatant,
            source: context.roster.hero.combatant,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "companionLeechSharePercent",
                for: context.roster.hero.combatant,
                fallback: "Symbiosis",
                in: context,
            ),
        )
    }

    static func applyLeechOverhealing(
        overflow: Int,
        request: HealRequest,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var events: [ActionEvent] = []
        if request.origin == .leech, sourceTriggers?.leechOverhealTransfersToCompanion == true,
           request.sourceActorID == context.hero.id, request.target.id == context.hero.id,
           context.roster.companion.isAlive {
            var transfer = HealRequest(
                amount: overflow, target: context.companion, sourceActorID: request.sourceActorID,
                origin: .leech, logAs: .silent,
            )
            transfer.amountBasis = .resolved
            let outcome = resolveHeal(transfer, in: &context)
            events.append(contentsOf: outcome.events)
            if outcome.healthRestored > 0 {
                events.append(context.nextEvent(
                    kind: .effect, effectKind: .leechHeal, actorName: context.hero.name,
                    abilityName: "Blood Link", target: context.companion,
                    amount: outcome.healthRestored, keyword: .leech,
                ))
            }
        }
        if request.origin == .leech, sourceTriggers?.marrowmend == true,
           request.sourceActorID == request.target.id {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: request.target))
            if block < 6 {
                events.append(contentsOf: context.applyBlock(
                    min(overflow, 6 - block), to: request.target, source: request.target,
                    abilityName: "Marrowmend", applyOutgoingAdjustment: false,
                ))
            }
        }
        if request.origin == .leech,
           let sourceActorID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            let bonus = context.modifiers(for: sourceActorID).triggers.leechOverhealDamageBonus
            if bonus > 0 {
                context.roster.mutateRuntime(for: source.combatant) { runtime in
                    let current = runtime.talentLeechOverhealDamageBonus
                    let allowed = max(0, 4 - current)
                    let toAdd = min(bonus, allowed)
                    if toAdd > 0 {
                        runtime.talentLeechOverhealDamageBonus += toAdd
                        runtime.permanentDamageBonus += toAdd
                    }
                }
            }
        }
        return events
    }
}
