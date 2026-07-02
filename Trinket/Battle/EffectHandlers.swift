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
        in context: inout BattleMutationContext,
        pairedDamageHits: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .burn(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(
            potency: potency,
            keyword: .burn,
            pairedDamageHits: pairedDamageHits
        )
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
        in context: inout BattleMutationContext,
        pairedDamageHits: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .poison(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(
            potency: potency,
            keyword: .poison,
            pairedDamageHits: pairedDamageHits
        )
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
        in context: inout BattleMutationContext,
        pairedDamageHits: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let skipImmediate = context.shouldSkipImmediateDoT(
            potency: potency,
            keyword: .bleed,
            pairedDamageHits: pairedDamageHits
        )
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .prevention(keyword, duration) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        guard context.health(of: target) > 0 else { return EffectApplyOutcome(events: [], didApply: false) }
        let preventionEffect = Effect.prevention(keyword, duration)
        let ae = ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: preventionEffect,
            remainingTicks: duration,
            sourceActorID: source.id
        )
        var currentEffects = context.activeEffects(for: target)
        currentEffects.append(ae)
        context.setActiveEffects(currentEffects, for: target)
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .shield(keyword, buffer, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .shield(adjustedKeyword, adjustedBuffer, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let ae = ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .shield(adjustedKeyword, adjustedBuffer, adjustedDuration),
            remainingTicks: adjustedDuration,
            sourceActorID: source.id
        )
        var currentEffects = context.activeEffects(for: target)
        currentEffects.append(ae)
        context.setActiveEffects(currentEffects, for: target)
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .mitigation(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let ae = ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration),
            remainingTicks: adjustedDuration,
            sourceActorID: source.id
        )
        var currentEffects = context.activeEffects(for: target)
        currentEffects.append(ae)
        context.setActiveEffects(currentEffects, for: target)
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .dodge(keyword, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let ae = ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: effect,
            remainingTicks: durationTicks,
            sourceActorID: source.id
        )
        var currentEffects = context.activeEffects(for: target)
        currentEffects.append(ae)
        context.setActiveEffects(currentEffects, for: target)
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .leech(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let wisdomTicks = source.primaryStats.wisdom / 20
        let ae = ActiveEffect(
            id: context.consumeNextEffectID(),
            effect: .leech(adjustedKeyword, adjustedPercent, adjustedDuration),
            remainingTicks: adjustedDuration + wisdomTicks,
            sourceActorID: source.id
        )
        var currentEffects = context.activeEffects(for: target)
        currentEffects.append(ae)
        context.setActiveEffects(currentEffects, for: target)
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
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
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
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

// MARK: - Cleanse handlers

struct CleanseHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanse
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let maxTicks = stacks.compactMap { eff -> Int? in
            if case let .cleanse(_, d) = eff.effect { return eff.remainingTicks > 0 ? eff.remainingTicks : d }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "Cleanse: \(maxTicks) ticks left.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .cleanse(targetKeyword, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)

        if let removeKeyword = targetKeyword {
            currentEffects.removeAll { $0.keyword == removeKeyword }
        } else {
            currentEffects.removeAll { $0.effect.isRemovableDebuff }
        }

        if durationTicks > 0 {
            let ae = ActiveEffect(
                id: context.consumeNextEffectID(),
                effect: effect,
                remainingTicks: durationTicks,
                sourceActorID: source.id
            )
            currentEffects.append(ae)
        }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: targetKeyword ?? .health
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct CleanseRandomHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanseRandom
    func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let debuffs = currentEffects.filter(\.effect.isRemovableDebuff)
        if let removed = debuffs.randomElement() {
            currentEffects.removeAll { $0.id == removed.id }
        }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: .health
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

// MARK: - Damage and debuff handlers

struct DealDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .dealDamage
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext,
        pairedDamageHits: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        guard case let .dealDamage(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let (typedDamage, typedEvents) = context.applyDamage(amount, to: target)
        var allEvents = typedEvents
        if typedDamage > 0 || amount > 0 {
            pairedDamageHits.append((keyword, amount))
        }
        if typedDamage > 0 {
            allEvents.append(context.nextEvent(
                kind: .ability,
                effectKind: nil,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: typedDamage,
                keyword: keyword
            ))
            if target.id != source.id {
                allEvents.append(contentsOf: context.applyLeechFromDamage(typedDamage, sourceActorID: source.id))
            }
        }
        return EffectApplyOutcome(events: allEvents, didApply: true)
    }
}

struct HalveMitigationHandler: BattleEffectHandler {
    let kind: EffectKind = .halveMitigation
    func apply(
        _ effect: Effect,
        ability: Ability,
        source _: Combatant,
        target: Combatant,
        in context: inout BattleMutationContext,
        pairedDamageHits _: inout [(Keyword, Int)]
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
        in context: inout BattleMutationContext,
        pairedDamageHits: inout [(Keyword, Int)]
    ) -> EffectApplyOutcome {
        // Buildup is created by `applyDamage` when stun/freeze damage lands;
        // an ability that targets `.preventionBuildup` directly is a no-op.
        _ = effect; _ = ability; _ = source; _ = target; _ = context; _ = pairedDamageHits
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
        .dealDamage: DealDamageHandler(),
        .halveMitigation: HalveMitigationHandler(),
        .dodge: DodgeHandler()
    ]
}
