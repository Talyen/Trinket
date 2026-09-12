import Foundation
import TrinketContent
import TrinketCore

struct ShieldFromResourceHandler: BattleEffectHandler {
    enum Mode {
        case convertManaToBlock
        case shieldFromMana
        case shieldFromHalfMana
        case shieldFromGold
    }

    let mode: Mode
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard effect.kind == kind else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let block: Int
        var payment: ManaPayment?
        switch mode {
        case .convertManaToBlock:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            payment = context.payMana(mana, for: target)
            block = mana
        case .shieldFromMana:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = mana
        case .shieldFromHalfMana:
            let half = context.mana(of: target) / 2
            guard half > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = half
        case .shieldFromGold:
            guard case let .shieldFromGold(goldPerBlock) = effect, goldPerBlock > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            let fromGold = context.gold / goldPerBlock
            guard fromGold > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = fromGold
        }

        let applied = context.applyBlockGain(
            block,
            to: target,
            source: source,
            abilityName: ability.name,
            origin: .direct,
        )
        var events: [ActionEvent] = []
        if let payment {
            events = CombatTriggerEngine.afterSpendMana(payment, in: &context)
        }
        events.append(contentsOf: applied.events)
        return EffectApplyOutcome(events: events, didApply: applied.applied > 0)
    }
}

struct MaximumManaBonusHandler: BattleEffectHandler {
    let kind: EffectKind = .maximumManaBonus

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .maximumManaBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Maximum Mana: Increases Maximum Mana by +\(total).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .maximumManaBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .maximumManaBonus(amount),
            to: target,
            sourceID: source.id,
            remainingTurns: 0,
        )
        let restored = context.restoreMana(
            context.paced(amount, sourceActorID: source.id),
            to: target,
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: max(amount, restored),
            keyword: .mana,
            origin: .direct,
        )
        var events = [event]
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct MultiplyDoTHandler: BattleEffectHandler {
    let kind: EffectKind = .multiplyDoT

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .multiplyDoT(keyword, factor) = effect, factor > 1 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        guard let index = effects.firstIndex(where: {
            $0.effect.keyword == keyword && ($0.effect.isDecayingDoT || $0.effect.isBleed)
        }) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let potency = effects[index].effect.potency ?? 0
        let multiplied = potency * factor
        switch keyword {
        case .burn:
            effects[index].effect = .burn(multiplied)
        case .poison:
            effects[index].effect = .poison(multiplied)
        case .bleed:
            effects[index].effect = .bleed(multiplied)
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(effects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .dotAmplified,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: multiplied,
            keyword: keyword,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct DetonateDoTHandler: BattleEffectHandler {
    let kind: EffectKind = .detonateDoT

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .detonateDoT(keyword, factor) = effect, factor > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.resolution.depth(.detonation) == 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }
        var effects = context.roster.activeEffects(for: target)
        let matching = effects.filter {
            $0.effect.keyword == keyword && ($0.effect.isDecayingDoT || $0.effect.isBleed)
        }
        guard !matching.isEmpty else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        effects.removeAll {
            $0.effect.keyword == keyword && ($0.effect.isDecayingDoT || $0.effect.isBleed)
        }
        context.roster.setActiveEffects(effects, for: target)
        var events: [ActionEvent] = []
        for active in matching {
            events.append(contentsOf: detonate(active, factor: factor, source: source, target: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func detonate(
        _ active: ActiveEffect,
        factor: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if active.effect.isBleed {
            var amplified = active
            amplified.effect = .bleed((active.effect.potency ?? 0) * factor)
            return CombatTriggerEngine.detonateBleedStacks(
                [amplified], on: target, sourceActorID: source.id,
                provenance: context.resolution.damageProvenance(for: source.id), in: &context,
            )
        }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        let slowBurn = sourceTriggers?.burnDecaySlowPercent ?? 0
        let tickCount = active.keyword == .burn && sourceTriggers?.burnTicksTwicePerTurn == true ? 2 : 1
        var remaining = active.effect
        var events: [ActionEvent] = []
        while context.roster.health(for: target) > 0 {
            let next = remaining.potencyAfterTurn(
                burnDecaySlowPercent: slowBurn, poisonDecaySlowPercent: sourceTriggers?.poisonDecaySlowPercent ?? 0,
            )
            guard next > 0 else { break }
            remaining = .decayingDoT(keyword: active.keyword, potency: next)
            for _ in 0 ..< tickCount where context.roster.health(for: target) > 0 {
                events.append(contentsOf: DoTDamage.resolveDamage(
                    basePotency: next * factor,
                    keyword: active.keyword,
                    target: target,
                    sourceActorID: source.id,
                    provenance: context.resolution.damageProvenance(for: source.id),
                    in: &context,
                ).events)
            }
        }
        return events
    }
}

struct RecurringDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .recurringDamage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .recurringDamage(damageKeyword, potency, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(damageKeyword.rawValue): Deals \(potency) \(damageKeyword.rawValue) damage each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .recurringDamage(keyword, potency, turns) = effect, potency > 0, turns > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let application = ActiveEffectMutation.replaceAndEmit(
            .recurringDamage(keyword, potency, turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: {
                if case let .recurringDamage(existingKeyword, _, _) = $0 {
                    return existingKeyword == keyword
                }
                return false
            },
            event: (.recurringDamageApplied, potency, keyword),
        )
        guard application.didApply else { return application }
        if UniqueCombatEngine.isOrdinaryAction(actorID: source.id, in: context) {
            context.uniques.card?.damageRequests.append(.doTTick(
                amount: potency,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
            ))
        }
        let events = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        ).events
        return EffectApplyOutcome(events: application.events + events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard case let .recurringDamage(keyword, potency, _) = active.effect,
              active.remainingTurns > 0
        else {
            return []
        }
        let sourceID = active.sourceActorID ?? target.id
        let events = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceID,
            in: &context,
        ).events
        if var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) {
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(
                active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
            )
        }
        return events
    }
}

struct AvatarHandler: BattleEffectHandler {
    let kind: EffectKind = .avatar

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .avatar(holyDamage, blockPerTurn, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "Avatar: Deals \(holyDamage) Holy damage and gains \(blockPerTurn) Block each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .avatar(holyDamage, blockPerTurn, turns) = effect,
              holyDamage > 0, blockPerTurn > 0, turns > 0
        else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let application = ActiveEffectMutation.replaceAndEmit(
            .avatar(holyDamage: holyDamage, blockPerTurn: blockPerTurn, turns: turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .avatar },
            event: (.avatarApplied, holyDamage, .holy),
        )
        guard application.didApply else { return application }
        let events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )
        return EffectApplyOutcome(events: application.events + events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard case let .avatar(holyDamage, blockPerTurn, _) = active.effect,
              active.remainingTurns > 0
        else {
            return []
        }
        let events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            in: &context,
        )
        if var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) {
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(
                active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
            )
        }
        return events
    }

    private func pulse(
        holyDamage: Int,
        blockPerTurn: Int,
        from caster: Combatant,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let opponent = BattleTargetResolver.abilityTarget(for: caster, in: context)
        var events = DoTDamage.resolveDamage(
            basePotency: holyDamage,
            keyword: .holy,
            target: opponent,
            sourceActorID: caster.id,
            provenance: provenance,
            in: &context,
        ).events
        events.append(contentsOf: context.applyBlock(
            blockPerTurn,
            to: caster,
            source: caster,
            abilityName: "Avatar",
        ))
        return events
    }
}

struct ReviveHandler: BattleEffectHandler {
    let kind: EffectKind = .revive

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .revive(health) = effect, health > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.roster.health(for: target) <= 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var revivedHealth = 0
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.currentHealth = min(health, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: revivedHealth,
            keyword: .health,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
