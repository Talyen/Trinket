import TrinketContent
import TrinketCore

extension EffectApplication {
    func applyBlessedAegis(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .blessedAegis(block, holyDamage) = effect else {
            return EffectApplyOutcome(didApply: false)
        }
        let allies = BattleActionContext(actor: source, in: context).allies(in: context)

        var didApply = false
        for ally in allies where context.health(of: ally) > 0 {
            guard context.health(of: source) > 0 else { break }
            // Route through effect dispatch so BlessedAegis always composes the
            // canonical handlers for these kinds rather than a private copy.
            let shield = await replacingEffect(
                .shield(.block, block), target: ally,
            ).apply(in: &context)

            let ward = await replacingEffect(
                .onHitDamage(.holy, holyDamage), target: ally,
            ).apply(in: &context)

            didApply = didApply || shield.didApply || ward.didApply
        }
        return EffectApplyOutcome(didApply: didApply)
    }
}
