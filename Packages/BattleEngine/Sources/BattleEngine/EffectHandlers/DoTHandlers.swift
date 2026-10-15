import TrinketContent
import TrinketCore

struct DecayingDoTHandler {
    let type: DecayingDoT

    var keyword: Keyword {
        type.keyword
    }

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) async {
        guard matches(active.effect) else { return }
        let progression = DecayingDoTProgression(
            type: type, sourceActorID: active.sourceActorID, target: target, in: context,
        )
        let nextPotency = progression.turnPotency(from: active.effect.potency ?? 0, using: &context.rng)
        var updated = active
        updated.effect = type.effect(potency: nextPotency)
        ActiveEffectMutation.finishTurn(active, replacement: nextPotency > 0 ? updated : nil, on: target, in: &context)
        if nextPotency > 0 {
            for _ in 0 ..< progression.ticksPerTurn {
                let outcome = await DoTDamage.resolveDamage(
                    basePotency: nextPotency,
                    keyword: keyword,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    operation: .resolvedPeriodic,
                    in: &context,
                )

                await CombatTriggerEngine.afterDoTTick(
                    keyword: keyword,
                    healthLost: outcome.healthLost,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    in: &context,
                )
            }
            return
        }

        if keyword == .poison {
            await CombatTriggerEngine.afterHeroTalentPoisonExpiry(sourceID: active.sourceActorID, target: target, in: &context)
        }
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .burn(potency) = active.effect, keyword == .burn {
                return SaturatedArithmetic.saturatingAdd(sum, potency)
            }
            if case let .poison(potency) = active.effect, keyword == .poison {
                return SaturatedArithmetic.saturatingAdd(sum, potency)
            }
            return sum
        }
        guard total > 0 else { return nil }
        if keyword == .burn {
            return EffectSummary(
                keyword: keyword,
                text: "\(total) Burn\nDeals Burn damage and halves each turn",
            )
        }
        return EffectSummary(
            keyword: keyword,
            text: "\(total) Poison\nDeals Poison damage and decreases by 25% each turn",
        )
    }

    private func matches(_ effect: Effect) -> Bool {
        effect.kind == type.kind
    }
}

extension EffectHandlers {
    static func advanceBleed(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) async {
        guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else {
            return
        }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        let isCritical = BattleChance.succeeds(
            probability: sourceTriggers?.bleedTickCritChancePercent ?? 0,
            using: &context.rng,
        )
        _ = await DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: .bleed,
            target: target,
            sourceActorID: active.sourceActorID,
            guaranteedCritical: isCritical,
            in: &context,
        )

        drawCardOnBleedTick(active: active, sourceTriggers: sourceTriggers, target: target, in: &context)

        if let sourceTriggers, sourceTriggers.bleedStripsBlockPerTurn > 0,
           let reduced = DefensePoolEngine.reduce(
               sourceTriggers.bleedStripsBlockPerTurn,
               in: context.roster.activeEffects(for: target),
           ) {
            context.roster.setActiveEffects(reduced.effects, for: target)
        }

        guard var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) else {
            return
        }
        if !shouldPreserveBleed(on: target, in: context) {
            updated.remainingTurns -= 1
            let remainingPotency = updated.effect.potency ?? 0
            if updated.remainingTurns == 0, sourceTriggers?.bleedHalvesAfterExpiration == true, remainingPotency > 1 {
                updated.effect = .bleed(remainingPotency / 2)
                updated.remainingTurns = 1
            }
        }
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
    }

    static func summarizeBleed(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, activeEffect in
            guard case let .bleed(potency) = activeEffect.effect, activeEffect.remainingTurns > 0 else {
                return sum
            }
            return SaturatedArithmetic.saturatingAdd(sum, potency)
        }
        guard total > 0 else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(total) Bleed\nDeals Bleed damage each turn until it expires",
        )
    }

    private static func drawCardOnBleedTick(
        active: ActiveEffect,
        sourceTriggers: CombatTraitTriggers?,
        target _: Combatant,
        in context: inout BattleState,
    ) {
        guard let attackerID = active.sourceActorID,
              let drawChance = sourceTriggers?.bleedTickDrawChancePercent, drawChance > 0,
              BattleChance.succeeds(probability: drawChance, using: &context.rng),
              let source = context.roster.combatant(for: attackerID),
              let owner = context.roster.participant(for: source.combatant), owner.isPartyMember
        else { return }
        guard BattleCardCombatEngine.drawFirstCard(matching: .physical, for: owner, context: &context) != nil else { return }
        context.nextEvent(
            kind: .effect(.cardsDrawn),
            source: .init(source.combatant),
            abilityName: CombatTriggerEngine.triggerAbilityName(
                .bleedTickDrawChancePercent,
                for: source.combatant,
                fallback: "Bloodrush",
                in: context,
            ),
            target: source.combatant,
            amount: 1,
            keyword: .physical,
        )
    }

    private static func shouldPreserveBleed(on target: Combatant, in context: BattleState) -> Bool {
        target.role == .enemy
            && context.roster.hasControlStatus(for: target, keyword: .freeze)
            && CombatTriggerEngine.hasLivingPartyTrigger(\.cryostasis, in: context)
    }

    static func summarizeRecurringDamage(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .recurringDamage(damageKeyword, potency, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(damageKeyword.rawValue): Deals \(potency) \(damageKeyword.rawValue) damage each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns))",
        )
    }

    static func advanceRecurringDamage(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) async {
        guard case let .recurringDamage(keyword, potency, _) = active.effect,
              active.remainingTurns > 0
        else {
            return
        }
        let sourceID = active.sourceActorID ?? target.id
        _ = await DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceID,
            in: &context,
        )
        if var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) {
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(
                active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
            )
        }
    }
}

extension EffectApplication {
    func applyRecurringDamage(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .recurringDamage(keyword, potency, turns) = effect, potency > 0, turns > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        let application = store(
            replacing: { $0.kind == .recurringDamage && $0.keyword == keyword },
            event: (.recurringDamageApplied, potency, keyword),
            in: &context,
        )
        guard application.didApply else { return application }
        var operation = DamageOperation.periodic
        operation.capturesCardRepeat = context.uniques.card?.repeatDamage == true
            && UniqueCombatEngine.isOrdinaryAction(actorID: source.id, in: context)
        _ = await DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
            operation: operation,
            in: &context,
        )

        return EffectApplyOutcome(didApply: true)
    }
}
