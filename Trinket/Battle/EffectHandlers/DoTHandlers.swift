import Foundation

struct DecayingDoTHandler: BattleEffectHandler {
    let keyword: Keyword

    var kind: EffectKind {
        switch keyword {
        case .burn: return .burn
        case .poison: return .poison
        default: preconditionFailure("Unsupported decaying DoT keyword \(keyword)")
        }
    }

    func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleMutationContext) -> EffectTickOutcome {
        guard matches(active.effect) else { return EffectTickOutcome() }
        let nextPotency = active.effect.potencyAfterTick()
        if nextPotency > 0 {
            let events = context.logDoTDamage(
                context.applyDoTDamage(nextPotency, keyword: keyword, to: target, sourceActorID: active.sourceActorID),
                keyword: keyword,
                target: target
            )
            var updated = active
            updated.effect = effectCase(potency: nextPotency)
            return EffectTickOutcome(events: events, updatedStack: updated)
        }

        var updated = active
        updated.effect = effectCase(potency: 0)
        return EffectTickOutcome(updatedStack: updated, removeAfter: true)
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard stacks.contains(where: \.effect.isDecayingDoT) else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue) active")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard let potency = effect.potency, matches(effect) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let skipImmediate = action.shouldSkipImmediateDoT(potency: potency, keyword: keyword)
        let events = context.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func matches(_ effect: Effect) -> Bool {
        switch (keyword, effect) {
        case (.burn, .burn), (.poison, .poison): return true
        default: return false
        }
    }

    private func effectCase(potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: preconditionFailure("Unsupported decaying DoT keyword \(keyword)")
        }
    }
}

struct BleedHandler: BattleEffectHandler {
    let kind: EffectKind = .bleed

    func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleMutationContext) -> EffectTickOutcome {
        guard case let .bleed(potency) = active.effect, active.remainingTicks > 0 else {
            return EffectTickOutcome()
        }
        let events = context.logDoTDamage(
            context.applyDoTDamage(potency, keyword: .bleed, to: target, sourceActorID: active.sourceActorID),
            keyword: .bleed,
            target: target
        )
        var updated = active
        updated.remainingTicks -= 1
        return EffectTickOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTicks <= 0
        )
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, activeEffect in
            guard case let .bleed(potency) = activeEffect.effect, activeEffect.remainingTicks > 0 else {
                return sum
            }
            return sum + potency
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) damage")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = action.shouldSkipImmediateDoT(potency: potency, keyword: .bleed)
        let events = context.applyBleed(
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
