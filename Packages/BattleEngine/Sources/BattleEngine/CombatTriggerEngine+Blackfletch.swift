import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func detonateBleedAndPoison(
        on target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard !context.isResolvingDoTDetonation else { return [] }
        context.isResolvingDoTDetonation = true
        defer { context.isResolvingDoTDetonation = false }

        let currentEffects = context.roster.activeEffects(for: target)
        let bleeds = currentEffects.compactMap { active -> (potency: Int, turns: Int)? in
            guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else { return nil }
            return (potency, active.remainingTurns)
        }
        let poisonPotency = currentEffects.reduce(0) { total, active in
            guard case let .poison(potency) = active.effect else { return total }
            return total + potency
        }
        guard !bleeds.isEmpty || poisonPotency > 0 else { return [] }

        context.roster.setActiveEffects(
            currentEffects.filter { active in
                !active.effect.isBleed && active.effect.keyword != .poison
            },
            for: target
        )

        var events: [ActionEvent] = []
        for (potency, turns) in bleeds {
            for _ in 0 ..< turns where context.roster.health(for: target) > 0 {
                events.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: potency,
                    keyword: .bleed,
                    target: target,
                    sourceActorID: sourceActorID,
                    in: &context
                ).events)
            }
        }

        var potency = poisonPotency
        while potency > 0, context.roster.health(for: target) > 0 {
            potency -= Effect.poisonDecayAmount(for: potency)
            guard potency > 0 else { break }
            events.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: potency,
                keyword: .poison,
                target: target,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }
        return events
    }
}
