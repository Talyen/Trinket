import Foundation
import TrinketCore
import TrinketContent

/// Healing and leech rules.
public enum HealingEngine {
    public static func resolveHeal(
        _ request: HealRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        let bonus = request.sourceActorID.map { context.modifiers(for: $0).healthRestoredBonus } ?? 0
        var restored = 0
        context.roster.mutateRuntime(for: request.target) { restored = $0.heal(request.amount + bonus) }

        var events: [ActionEvent] = []
        switch request.logAs {
        case .silent, .leech:
            break
        case let .instantHeal(actorName, abilityName, keyword, displayAmount):
            events.append(
                context.nextEvent(
                    kind: .effect,
                    effectKind: .instantHeal,
                    actorName: actorName,
                    abilityName: abilityName,
                    target: request.target,
                    amount: displayAmount,
                    keyword: keyword
                )
            )
        }

        return CombatOutcome(healthDelta: restored, events: events, flags: [])
    }

    public static func leechFromDamage(
        _ damage: Int,
        sourceActorID: String,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard damage > 0, let actor = context.roster.combatant(for: sourceActorID) else { return .empty }
        let actorCombatant = actor.combatant

        let leechPct = context.roster.activeEffects(for: actorCombatant).reduce(0.0) { sum, activeEffect in
            if case let .leech(_, percent, _) = activeEffect.effect { return sum + percent }
            return sum
        }
        guard leechPct > 0 else { return .empty }

        let wisdomPercent = Double(actorCombatant.primaryStats.wisdom) * 0.001
        let totalPct = leechPct + wisdomPercent
        var restored = Int(ceil(Double(damage) * totalPct))
        restored += context.modifiers(for: sourceActorID).leechHealingBonus
        guard restored > 0 else { return .empty }

        _ = resolveHeal(
            HealRequest(amount: restored, target: actorCombatant, logAs: .silent),
            in: &context
        )

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .leechHeal,
            actorName: actorCombatant.name,
            abilityName: "Leech",
            target: actorCombatant,
            amount: restored,
            keyword: .leech,
            appliedEffectSummaries: [],
            milestone: nil
        )
        return CombatOutcome(healthDelta: restored, events: [event], flags: [.leeched])
    }
}
