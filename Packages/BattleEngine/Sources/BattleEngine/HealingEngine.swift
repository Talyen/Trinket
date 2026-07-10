import Foundation
import TrinketContent
import TrinketCore

/// Healing and leech rules.
package enum HealingEngine {
    static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard context.roster.health(for: request.target) > 0 else { return .empty }
        if context.modifiers(for: request.target.id).cannotBeHealed {
            return .empty
        }
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(request.amount + bonus) }

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
                    keyword: keyword
                )
            )
        }

        if !request.suppressTraitReactions,
           request.target.id == context.roster.hero.id,
           restored > 0 {
            events.append(contentsOf: CombatReactionEngine.shareHeroHealWithPet(
                restored: restored,
                in: &context
            ))
        }

        if !request.suppressTraitReactions,
           let sourceActorID = request.sourceActorID,
           let source = context.roster.combatant(for: sourceActorID)?.combatant,
           restored > 0 {
            events.append(contentsOf: TraitReactionEngine.healHeroAfterRestore(
                source: source,
                hero: context.roster.hero.combatant,
                in: &context
            ).events)
        }

        return CombatOutcome(healthDelta: restored, events: events, flags: [])
    }

    static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        abilityHasLeech: Bool = false,
        in context: inout BattleEngineContext
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
            if case let .leech(_, percent, _) = activeEffect.effect { return max(maxPercent, percent) }
            return maxPercent
        }
        leechPct = max(leechPct, buffPct)
        guard leechPct > 0 else { return .empty }

        var restored = Int(ceil(Double(damage) * leechPct))
        let profile = context.modifiers(for: sourceActorID)
        restored = Int(ceil(Double(restored) * profile.leechHealingMultiplier))
        restored += profile.leechHealingBonus
        guard restored > 0 else { return .empty }

        let healOutcome = resolveHeal(
            HealRequest(
                amount: restored,
                target: actorCombatant,
                sourceActorID: sourceActorID,
                logAs: .silent
            ),
            in: &context
        )
        guard healOutcome.healthRestored > 0 else { return .empty }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .leechHeal,
            actorName: actorCombatant.name,
            abilityName: "Leech",
            target: actorCombatant,
            amount: healOutcome.healthRestored,
            keyword: .leech,
            appliedEffectSummaries: [],
            milestone: nil
        )
        return CombatOutcome(healthDelta: healOutcome.healthRestored, events: [event], flags: [.leeched])
    }
}
