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
        guard let first = context.roster.activeEffects(for: target).first(where: { isDetonatableDoT($0.effect, keyword: keyword) }),
              !CombatTriggerEngine.preventsDebuff(first.effect, on: target, in: context)
        else {
            return EffectApplyOutcome(didApply: false)
        }
        guard context.roster.activeEffects(for: target).contains(where: {
            isDetonatableDoT($0.effect, keyword: keyword)
                && SaturatedArithmetic.saturatingMul($0.effect.potency ?? 0, factor) > ($0.effect.potency ?? 0)
        }) else { return EffectApplyOutcome(didApply: false) }
        var total = 0
        context.roster.mutateEffects(for: target) { effects in
            for index in effects.indices where isDetonatableDoT(effects[index].effect, keyword: keyword) {
                let potency = effects[index].effect.potency ?? 0
                let multiplied = SaturatedArithmetic.saturatingMul(potency, factor)
                switch keyword {
                case .burn: effects[index].effect = .burn(multiplied)
                case .poison: effects[index].effect = .poison(multiplied)
                case .bleed: effects[index].effect = .bleed(multiplied)
                default: break
                }
                total = SaturatedArithmetic.saturatingAdd(total, multiplied)
            }
        }
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
        var matching: [ActiveEffect] = []
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.removeAll { active in
                guard isDetonatableDoT(active.effect, keyword: keyword) else { return false }
                matching.append(active)
                return true
            }
        }
        guard !matching.isEmpty else {
            return EffectApplyOutcome(didApply: false)
        }
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
