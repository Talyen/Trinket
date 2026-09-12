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
            let shield = BlockBuffHandler().apply(.shield(.block, block), ability: ability, source: source, target: ally, in: &context)
            events.append(contentsOf: shield.events)
            let ward = OnHitDamageHandler().apply(
                .onHitDamage(.holy, holyDamage),
                ability: ability,
                source: source,
                target: ally,
                in: &context,
            )
            events.append(contentsOf: ward.events)
            didApply = didApply || shield.didApply || ward.didApply
        }
        return EffectApplyOutcome(events: events, didApply: didApply)
    }
}
