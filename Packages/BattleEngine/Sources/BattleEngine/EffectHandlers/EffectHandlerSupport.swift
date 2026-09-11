import Foundation
import TrinketContent
import TrinketCore

enum EffectRemoval {
    @discardableResult
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableDebuff }
    }

    static func removeRandomDebuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
    ) -> ActiveEffect? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableDebuff }
    }

    @discardableResult
    static func removeBuffs(
        from effects: inout [ActiveEffect], keyword: Keyword?, preservingBlock: Bool = false,
    ) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) {
            $0.effect.isRemovableBuff && !(preservingBlock && $0.effect.kind == .shield)
        }
    }

    static func removeRandomBuff(
        from effects: inout [ActiveEffect],
        preservingBlock: Bool = false,
        using rng: inout SeededRandomNumberGenerator,
    ) -> ActiveEffect? {
        removeRandom(from: &effects, using: &rng) {
            $0.effect.isRemovableBuff && !(preservingBlock && $0.effect.kind == .shield)
        }
    }

    static func removeBuffs(
        from effects: inout [ActiveEffect],
        count: Int,
        removeAll: Bool,
        preservingBlock: Bool = false,
        using rng: inout SeededRandomNumberGenerator,
    ) -> [ActiveEffect] {
        if removeAll {
            return removeBuffs(from: &effects, keyword: nil, preservingBlock: preservingBlock)
        }

        var removed: [ActiveEffect] = []
        for _ in 0 ..< count {
            guard let keyword = removeRandomBuff(from: &effects, preservingBlock: preservingBlock, using: &rng) else { break }
            removed.append(keyword)
        }
        return removed
    }

    @discardableResult
    private static func removeMatching(
        from effects: inout [ActiveEffect],
        keyword: Keyword?,
        where matches: (ActiveEffect) -> Bool,
    ) -> [ActiveEffect] {
        var removed: [ActiveEffect] = []
        var remaining: [ActiveEffect] = []
        for effect in effects {
            let isMatch = matches(effect) && (keyword == nil || effect.keyword == keyword)
            if isMatch {
                removed.append(effect)
            } else {
                remaining.append(effect)
            }
        }
        effects = remaining
        return removed
    }

    private static func removeRandom(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
        where matches: (ActiveEffect) -> Bool,
    ) -> ActiveEffect? {
        let candidates = effects.filter(matches)
        guard let removed = candidates.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed
    }
}

enum TimedBuffSummary {
    static func minRemainingTurns(in stacks: [ActiveEffect], duration: (Effect) -> Int?) -> Int {
        stacks.compactMap { active -> Int? in
            guard let baseDuration = duration(active.effect) else { return nil }
            return active.remainingTurns > 0 ? active.remainingTurns : baseDuration
        }.min() ?? 0
    }
}

enum ActiveEffectMutation {
    static func finishTurn(
        _ active: ActiveEffect,
        replacement: ActiveEffect?,
        on target: Combatant,
        in context: inout BattleState,
    ) {
        context.roster.mutateRuntime(for: target) { runtime in
            guard let index = runtime.activeEffects.firstIndex(where: { $0.id == active.id }) else { return }
            if let replacement {
                runtime.activeEffects[index] = replacement
            } else {
                runtime.activeEffects.remove(at: index)
            }
        }
    }

    static func removeMatching(
        from target: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool,
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { matches($0.effect) }
        context.roster.setActiveEffects(effects, for: target)
    }

    static func replaceAndEmit(
        _ effect: Effect,
        to target: Combatant,
        source: Combatant,
        ability: Ability,
        in context: inout BattleState,
        replacing matches: (Effect) -> Bool,
        event: (kind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword),
    ) -> EffectApplyOutcome {
        guard context.insertEffect(
            effect, to: target, sourceID: source.id, remainingTurns: effect.durationTurns, replacing: matches,
        ) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let appliedEvent = context.nextEvent(
            kind: .effect,
            effectKind: event.kind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: event.amount,
            keyword: event.keyword,
            origin: .direct,
        )
        return EffectApplyOutcome(events: [appliedEvent], didApply: true)
    }

    static func reflect(
        _ active: ActiveEffect,
        to target: Combatant,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        switch active.effect {
        case let .burn(potency), let .poison(potency):
            return context.applyDecayingDoT(
                keyword: active.keyword, potency: potency, to: target, sourceActorID: source.id, application: .reflection,
            )
        case let .bleed(potency):
            return DoTApplicator.applyBleed(
                potency: potency, to: target, sourceActorID: source.id, application: .reflection,
                durationTurns: active.remainingTurns, in: &context,
            )
        case let .controlMeter(keyword, amount, _):
            return ControlMeterEngine.applyMeterCharge(
                amount, keyword: keyword, to: target, sourceActorID: source.id, applyFightPacing: false, in: &context,
            )
        default:
            context.appendEffect(active.effect, to: target, sourceID: source.id, remainingTurns: active.remainingTurns)
            return []
        }
    }
}
