import Foundation
import TrinketContent
import TrinketCore

private func isDetonatableDoT(_ effect: Effect, keyword: Keyword) -> Bool {
    effect.keyword == keyword && (effect.isDecayingDoT || effect.isBleed)
}

struct MultiplyDoTHandler: BattleEffectHandler {
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
            isDetonatableDoT($0.effect, keyword: keyword)
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
            isDetonatableDoT($0.effect, keyword: keyword)
        }
        guard !matching.isEmpty else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        effects.removeAll {
            isDetonatableDoT($0.effect, keyword: keyword)
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
        return DecayingDoTDetonation.resolve(
            active,
            factor: factor,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )
    }
}
