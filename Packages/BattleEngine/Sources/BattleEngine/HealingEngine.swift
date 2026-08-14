import Foundation
import TrinketContent
import TrinketCore

/// Healing and leech rules.
package enum HealingEngine {
    static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard context.roster.health(for: request.target) > 0 else { return .empty }
        if context.modifiers(for: request.target.id).triggers.cannotBeHealed {
            return .empty
        }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var amount = request.amount + bonus
        if request.logAs != .leech, let sourceActorID = request.sourceActorID {
            amount = context.paced(amount, sourceActorID: sourceActorID)
        }
        var flags: Set<CombatFlag> = []

        if let crit = rollRestorationCritical(for: request, amount: &amount, in: &context) {
            flags.insert(crit)
        }

        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(amount) }

        var events: [ActionEvent] = []
        switch request.logAs {
        case .silent, .leech:
            break
        case let .instantHeal(actorName, abilityName, keyword, _):
            events.append(
                context.nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: actorName,
                    abilityName: abilityName,
                    target: request.target,
                    amount: restored,
                    keyword: keyword,
                    isCritical: flags.contains(.critical)
                )
            )
        }
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterHealthRestored(
                restored,
                to: request.target,
                in: &context
            ))
        }

        return CombatOutcome(healthDelta: restored, events: events, flags: flags)
    }

    // swiftlint:disable:next function_body_length
    static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        abilityHasLeech: Bool = false,
        damageKeyword: Keyword? = nil,
        in context: inout BattleState
    ) -> CombatOutcome {
        guard damage > 0,
              let actor = context.roster.combatant(for: sourceActorID),
              context.roster.health(for: actor.combatant) > 0
        else { return .empty }
        let actorCombatant = actor.combatant

        var leechPct = 0.0
        if abilityHasLeech {
            leechPct = Effect.abilityLeechPercent
        }
        let buffPct = context.roster.activeEffects(for: actorCombatant).reduce(0.0) { maxPercent, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect {
                return max(maxPercent, percent)
            }
            return maxPercent
        }
        leechPct = max(leechPct, buffPct)
        let profile = context.modifiers(for: sourceActorID)
        let keywordGrantsLeech = damageKeyword == .freeze && profile.triggers.freezeDamageLeech
            || damageKeyword == .poison && profile.triggers.poisonDamageLeech
        if leechPct == 0, keywordGrantsLeech {
            leechPct = Effect.abilityLeechPercent
        }
        if leechPct == 0,
           BattleChance.succeeds(probability: profile.triggers.leechChancePercent, using: &context.rng) {
            leechPct = Effect.abilityLeechPercent
        }
        guard leechPct > 0 else { return .empty }
        leechPct += profile.leechGainedBonus

        var restored = CombatRounding.scaled(damage, multiplier: leechPct)
        restored = CombatRounding.scaled(restored, multiplier: profile.triggers.leechHealingMultiplier)
        restored += profile.leechHealingBonus
        guard restored > 0 else { return .empty }

        let healOutcome = resolveHeal(
            HealRequest(
                amount: restored,
                target: actorCombatant,
                sourceActorID: sourceActorID,
                logAs: .leech
            ),
            in: &context
        )
        guard healOutcome.healthRestored > 0 else { return .empty }

        var events = [context.nextEvent(
            kind: .effect,
            effectKind: .leechHeal,
            actorName: actorCombatant.name,
            abilityName: "Leech",
            target: actorCombatant,
            amount: healOutcome.healthRestored,
            keyword: .leech,
            appliedEffectSummaries: [],
            milestone: nil,
            isCritical: healOutcome.isCritical
        )]
        if actorCombatant.id == context.roster.hero.id {
            events.append(contentsOf: CombatTriggerEngine.shareHeroLeechWithCompanion(
                restored: healOutcome.healthRestored,
                in: &context
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.afterLeech(by: actorCombatant, in: &context))
        var flags = healOutcome.flags
        flags.insert(.leeched)
        return CombatOutcome(healthDelta: healOutcome.healthRestored, events: events, flags: flags)
    }

    /// Rolls Wisdom-scaled restoration crit for Health / Leech heals. Doubles the
    /// heal amount in place when it hits. Returns `.critical` when the roll succeeds.
    private static func rollRestorationCritical(
        for request: HealRequest,
        amount: inout Int,
        in context: inout BattleState
    ) -> CombatFlag? {
        guard amount > 0,
              let sourceActorID = request.sourceActorID,
              let actor = context.roster.combatant(for: sourceActorID)
        else { return nil }

        let critKeyword: Keyword
        switch request.logAs {
        case let .instantHeal(_, _, keyword, _):
            critKeyword = keyword
        case .leech:
            critKeyword = .leech
        case .silent:
            return nil
        }
        guard critKeyword.allowsCriticalHits else { return nil }

        var chance = actor.primaryStats.contestedCriticalChance(
            for: critKeyword,
            againstDefenderToughness: request.target.primaryStats.toughness
        )
        chance += context.modifiers(for: sourceActorID).triggers.criticalChanceBonus
        for active in context.roster.activeEffects(for: actor.combatant) {
            if case let .criticalChanceBonus(bonus, _) = active.effect {
                chance += bonus
            }
        }
        let cap = DamagePipeline.criticalChanceCap(for: actor.combatant)
        chance = min(cap, max(0, chance))
        guard BattleChance.succeeds(probability: chance, using: &context.rng) else { return nil }

        amount *= 2
        return .critical
    }
}
