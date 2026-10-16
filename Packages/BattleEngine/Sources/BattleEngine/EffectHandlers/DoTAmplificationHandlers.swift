import TrinketContent
import TrinketCore

private func isDetonatableDoT(_ effect: Effect, keyword: Keyword) -> Bool {
    effect.keyword == keyword && (effect.isDecayingDoT || effect.isBleed)
}

extension EffectApplication {
    func applyMultiplyDoT(in context: inout BattleState) -> EffectApplyOutcome {
        guard case let .multiplyDoT(keyword, factor) = effect, factor > 1 else {
            return EffectApplyOutcome(didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        let indices = effects.indices.filter {
            isDetonatableDoT(effects[$0].effect, keyword: keyword)
        }
        guard let firstIndex = indices.first,
              !CombatTriggerEngine.preventsDebuff(effects[firstIndex].effect, on: target, in: context)
        else {
            return EffectApplyOutcome(didApply: false)
        }
        var total = 0
        for index in indices {
            let multiplied = SaturatedArithmetic.saturatingMul(effects[index].effect.potency ?? 0, factor)
            switch keyword {
            case .burn: effects[index].effect = .burn(multiplied)
            case .poison: effects[index].effect = .poison(multiplied)
            case .bleed: effects[index].effect = .bleed(multiplied)
            default: return EffectApplyOutcome(didApply: false)
            }
            total = SaturatedArithmetic.saturatingAdd(total, multiplied)
        }
        context.roster.setActiveEffects(effects, for: target)
        emit(.dotAmplified, amount: total, keyword: keyword, origin: .automatic, in: &context)
        return EffectApplyOutcome(didApply: true)
    }

    func applyDetonateDoT(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .detonateDoT(keyword, factor) = effect, factor > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        guard context.resolution.depth(.detonation) == 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }
        var effects = context.roster.activeEffects(for: target)
        let matching = effects.filter {
            isDetonatableDoT($0.effect, keyword: keyword)
        }
        guard !matching.isEmpty else {
            return EffectApplyOutcome(didApply: false)
        }
        effects.removeAll {
            isDetonatableDoT($0.effect, keyword: keyword)
        }
        context.roster.setActiveEffects(effects, for: target)

        for active in matching {
            await detonate(active, factor: factor, in: &context)
        }
        return EffectApplyOutcome(didApply: true)
    }

    private func detonate(
        _ active: ActiveEffect,
        factor: Int,
        in context: inout BattleState,
    ) async {
        if active.effect.isBleed {
            var amplified = active
            amplified.effect = .bleed(SaturatedArithmetic.saturatingMul(active.effect.potency ?? 0, factor))
            await CombatTriggerEngine.detonateBleedStacks(
                [amplified], on: target, sourceActorID: source.id,
                provenance: context.resolution.damageProvenance(for: source.id), in: &context,
            )
            return
        }
        await DecayingDoTDetonation.resolve(
            active,
            factor: factor,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )
    }
}
