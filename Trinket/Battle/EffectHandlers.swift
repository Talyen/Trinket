import Foundation

// MARK: - DoT handlers (burn, poison, bleed)

struct BurnHandler: BattleEffectHandler {
    let kind: EffectKind = .burn
    func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleMutationContext) -> EffectTickOutcome {
        guard case .burn = active.effect else { return EffectTickOutcome() }
        let nextPotency = active.effect.potencyAfterTick()
        if nextPotency > 0 {
            let events = context.logDoTDamage(
                context.applyDoTDamage(nextPotency, keyword: .burn, to: target, sourceActorID: active.sourceActorID),
                keyword: .burn,
                target: target
            )
            var updated = active
            updated.effect = .burn(nextPotency)
            return EffectTickOutcome(events: events, updatedStack: updated)
        } else {
            var updated = active
            updated.effect = .burn(0)
            return EffectTickOutcome(updatedStack: updated, removeAfter: true)
        }
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
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .burn(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(potency: potency, keyword: .burn)
        let events = context.applyDecayingDoT(
            keyword: .burn,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct PoisonHandler: BattleEffectHandler {
    let kind: EffectKind = .poison
    func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleMutationContext) -> EffectTickOutcome {
        guard case .poison = active.effect else { return EffectTickOutcome() }
        let nextPotency = active.effect.potencyAfterTick()
        if nextPotency > 0 {
            let events = context.logDoTDamage(
                context.applyDoTDamage(nextPotency, keyword: .poison, to: target, sourceActorID: active.sourceActorID),
                keyword: .poison,
                target: target
            )
            var updated = active
            updated.effect = .poison(nextPotency)
            return EffectTickOutcome(events: events, updatedStack: updated)
        } else {
            var updated = active
            updated.effect = .poison(0)
            return EffectTickOutcome(updatedStack: updated, removeAfter: true)
        }
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
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .poison(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(potency: potency, keyword: .poison)
        let events = context.applyDecayingDoT(
            keyword: .poison,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
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
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(potency: potency, keyword: .bleed)
        let events = context.applyBleed(
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

// MARK: - Defensive buff handlers

struct PreventionHandler: BattleEffectHandler {
    let kind: EffectKind = .prevention
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let maxActions = stacks.compactMap { eff -> Int? in
            if case .prevention = eff.effect {
                return eff.remainingTicks
            }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(maxActions) actions prevented.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .prevention(keyword, duration) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        guard context.health(of: target) > 0 else { return EffectApplyOutcome(events: [], didApply: false) }
        context.appendEffect(
            .prevention(keyword, duration),
            to: target,
            sourceID: source.id,
            remainingTicks: duration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .preventionApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ShieldHandler: BattleEffectHandler {
    let kind: EffectKind = .shield
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, effect in
            if case let .shield(_, b, _) = effect.effect { return sum + b }
            return sum
        }
        guard total > 0 else { return nil }
        let maxTicks = stacks.compactMap { eff -> Int? in
            if case let .shield(_, _, d) = eff.effect { return eff.remainingTicks > 0 ? eff.remainingTicks : d }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) buffer, \(maxTicks) ticks left.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .shield(keyword, buffer, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .shield(adjustedKeyword, adjustedBuffer, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .shield(adjustedKeyword, adjustedBuffer, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: adjustedBuffer,
            keyword: adjustedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct MitigationHandler: BattleEffectHandler {
    let kind: EffectKind = .mitigation
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let totalPct = stacks.reduce(0.0) { sum, effect in
            if case let .mitigation(_, p, _) = effect.effect { return sum + p }
            return sum
        }
        guard totalPct > 0 else { return nil }
        let maxTicks = stacks.compactMap { eff -> Int? in
            if case let .mitigation(_, _, d) = eff.effect { return eff.remainingTicks > 0 ? eff.remainingTicks : d }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(totalPct * 100))% mitigation, \(maxTicks) ticks left.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .mitigation(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .mitigationApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: Int(adjustedPercent * 100),
            keyword: adjustedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct DodgeHandler: BattleEffectHandler {
    let kind: EffectKind = .dodge
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let maxTicks = stacks.compactMap { eff -> Int? in
            if case let .dodge(_, d) = eff.effect { return eff.remainingTicks > 0 ? eff.remainingTicks : d }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(maxTicks) ticks.")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .dodge(keyword, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.appendEffect(effect, to: target, sourceID: source.id, remainingTicks: durationTicks)
        _ = keyword
        return EffectApplyOutcome(events: [], didApply: true)
    }
}

struct LeechHandler: BattleEffectHandler {
    let kind: EffectKind = .leech
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let totalPct = stacks.reduce(0.0) { sum, effect in
            if case let .leech(_, p, _) = effect.effect { return sum + p }
            return sum
        }
        guard totalPct > 0 else { return nil }
        let maxTicks = stacks.compactMap { eff -> Int? in
            if case let .leech(_, _, d) = eff.effect { return eff.remainingTicks > 0 ? eff.remainingTicks : d }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(totalPct * 100))% leech, \(maxTicks) ticks left.")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .leech(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let wisdomTicks = source.primaryStats.wisdom / 20
        context.appendEffect(
            .leech(adjustedKeyword, adjustedPercent, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration + wisdomTicks
        )
        _ = keyword
        return EffectApplyOutcome(events: [], didApply: true)
    }
}

// MARK: - Restoration handlers

struct InstantHealHandler: BattleEffectHandler {
    let kind: EffectKind = .instantHeal
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.applyHeal(amount, to: target, sourceActorID: source.id)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ResourceGainHandler: BattleEffectHandler {
    let kind: EffectKind = .resourceGain
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.addGold(amount, sourceActorID: source.id)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

// MARK: - Cleanse and purge handlers

enum EffectRemoval {
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) {
        if let keyword {
            effects.removeAll { $0.keyword == keyword && $0.effect.isRemovableDebuff }
        } else {
            effects.removeAll { $0.effect.isRemovableDebuff }
        }
    }

    static func removeRandomDebuff(from effects: inout [ActiveEffect], using rng: inout SeededRandomNumberGenerator) -> Keyword? {
        let debuffs = effects.filter(\.effect.isRemovableDebuff)
        guard let removed = debuffs.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }

    static func removeBuffs(from effects: inout [ActiveEffect], keyword: Keyword?) {
        if let keyword {
            effects.removeAll { $0.keyword == keyword && $0.effect.isRemovableBuff }
        } else {
            effects.removeAll { $0.effect.isRemovableBuff }
        }
    }

    static func removeRandomBuff(from effects: inout [ActiveEffect], using rng: inout SeededRandomNumberGenerator) -> Keyword? {
        let buffs = effects.filter(\.effect.isRemovableBuff)
        guard let removed = buffs.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }
}

struct CleanseHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanse
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .cleanse(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        removeDebuffs(from: &currentEffects, keyword: targetKeyword)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = targetKeyword ?? .health
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }

    private func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) {
        EffectRemoval.removeDebuffs(from: &effects, keyword: keyword)
    }
}

struct CleanseRandomHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanseRandom
    func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = removedKeyword ?? .health
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct PurgeHandler: BattleEffectHandler {
    let kind: EffectKind = .purge
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .purge(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = targetKeyword ?? .purge
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct PurgeRandomHandler: BattleEffectHandler {
    let kind: EffectKind = .purgeRandom
    func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = removedKeyword ?? .purge
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

// MARK: - Damage and debuff handlers

struct HalveMitigationHandler: BattleEffectHandler {
    let kind: EffectKind = .halveMitigation
    func apply(
        _ effect: Effect,
        ability: Ability,
        source _: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .halveMitigation(keyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        for index in currentEffects.indices {
            if case let .mitigation(mitigationKeyword, percent, duration) = currentEffects[index].effect,
               mitigationKeyword == keyword {
                currentEffects[index].effect = .mitigation(
                    mitigationKeyword,
                    percent / 2,
                    duration
                )
            }
        }
        context.setActiveEffects(currentEffects, for: target)
        _ = ability
        return EffectApplyOutcome(events: [], didApply: true)
    }
}

struct PreventionBuildupHandler: BattleEffectHandler {
    let kind: EffectKind = .preventionBuildup
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.compactMap { eff -> Int? in
            if case let .preventionBuildup(_, amt, _) = eff.effect { return amt }
            return nil
        }.reduce(0, +)
        let threshold = stacks.compactMap { eff -> Int? in
            if case let .preventionBuildup(_, _, th) = eff.effect { return th }
            return nil
        }.max() ?? 1
        return EffectSummary(
            keyword: keyword,
            text: "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        // Buildup is created by `applyDamage` when stun/freeze damage lands;
        // an ability that targets `.preventionBuildup` directly is a no-op.
        _ = effect; _ = ability; _ = source; _ = target; _ = context
        return EffectApplyOutcome(events: [], didApply: false)
    }
}

// MARK: - Registry

/// Lookup table of every `BattleEffectHandler`, keyed by `EffectKind`.
/// `performAction` resolves each targeted effect through this table instead
/// of a single inline switch.
enum EffectHandlers {
    static let all: [EffectKind: any BattleEffectHandler] = [
        .burn: BurnHandler(),
        .poison: PoisonHandler(),
        .bleed: BleedHandler(),
        .prevention: PreventionHandler(),
        .preventionBuildup: PreventionBuildupHandler(),
        .shield: ShieldHandler(),
        .mitigation: MitigationHandler(),
        .instantHeal: InstantHealHandler(),
        .leech: LeechHandler(),
        .resourceGain: ResourceGainHandler(),
        .cleanse: CleanseHandler(),
        .cleanseRandom: CleanseRandomHandler(),
        .purge: PurgeHandler(),
        .purgeRandom: PurgeRandomHandler(),
        .halveMitigation: HalveMitigationHandler(),
        .dodge: DodgeHandler()
    ]
}
