import TrinketContent
import TrinketCore

struct BlessedAegisHandler: BattleEffectHandler {
    let kind: EffectKind = .blessedAegis

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target _: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .blessedAegis(block, holyDamage) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let allies = BattleActionContext(actor: source, in: context).allies(in: context)
        var events: [ActionEvent] = []
        var didApply = false
        for ally in allies where context.health(of: ally) > 0 {
            guard context.health(of: source) > 0 else { break }
            // Route through the registry so BlessedAegis always composes the
            // canonical handlers for these kinds rather than a private copy.
            let shield = applyViaRegistry(
                .shield, .shield(.block, block), ability: ability, source: source, target: ally, in: &context,
            )
            events.append(contentsOf: shield.events)
            let ward = applyViaRegistry(
                .onHitDamage, .onHitDamage(.holy, holyDamage),
                ability: ability, source: source, target: ally, in: &context,
            )
            events.append(contentsOf: ward.events)
            didApply = didApply || shield.didApply || ward.didApply
        }
        return EffectApplyOutcome(events: events, didApply: didApply)
    }

    private func applyViaRegistry(
        _ kind: EffectKind,
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let handler = EffectHandlers.handler(for: kind) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return handler.apply(effect, ability: ability, source: source, target: target, in: &context)
    }
}
