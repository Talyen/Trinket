import TrinketContent
import TrinketCore

extension CombatTriggerEngine {
    static func heroTalentThorns(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        let total = context.roster.activeEffects(for: target).reduce(1) { sum, active in
            if case let .thorns(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) { $0.kind == .thorns }
        context.appendEffect(.thorns(total), to: target, sourceID: source.id, remainingTurns: 0)
        return [context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: source.name,
            abilityName: name,
            target: target,
            amount: 1,
            keyword: .physical,
        )]
    }

    static func heroTalentHeal(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 1, target: target, sourceActorID: source.id, logAs: .silent), in: &context,
        )
        guard outcome.healthRestored > 0 else { return outcome.events }
        return outcome.events + [context.nextEvent(
            kind: .effect, effectKind: .instantHeal, actorName: source.name,
            abilityName: name, target: target, amount: outcome.healthRestored, keyword: .health,
        )]
    }

    static func heroTalentMana(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        return context.restoreManaEmitting(1, to: target, abilityName: name)
    }

    static func heroTalentGold(to source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        return context.grantGoldEvent(1, to: source, abilityName: name)
    }

    static func heroTalentBlock(to target: Combatant, source: Combatant, name: String, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.health(for: target) > 0, context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        return context.applyBlock(1, to: target, source: source, abilityName: name)
    }

    static func heroTalentDamage(_ keyword: Keyword, source: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard context.roster.enemy.isAlive, context.roster.health(for: source) > 0 else { return [] }
        context.heroTalents.reactionDepth += 1
        defer { context.heroTalents.reactionDepth -= 1 }
        let target = context.roster.enemy.combatant
        var events = context.resolveDamage(DamageRequest(
            amount: 1,
            target: target,
            keyword: keyword,
            sourceActorID: source.id,
            options: keyword == .freeze || keyword == .stun ? .flatControlReaction : .flatReaction,
        )).events
        if keyword == .burn || keyword == .poison {
            events.append(contentsOf: context.applyDecayingDoT(
                keyword: keyword,
                potency: 1,
                to: target,
                sourceActorID: source.id,
                dealImmediateDamage: false,
            ))
        }
        return events
    }
}
