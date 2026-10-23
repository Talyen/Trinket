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
            for effect in Self.aegisEffects(block: block, holyDamage: holyDamage) {
                let outcome = await replacingEffect(effect, target: ally).apply(in: &context)
                didApply = didApply || outcome.didApply
            }
        }
        return EffectApplyOutcome(didApply: didApply)
    }
}
