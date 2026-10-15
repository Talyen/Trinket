import TrinketContent
import TrinketCore

struct BlockBuffHandler: BattleEffectHandler {
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = DefensePoolEngine.blockPoints(in: stacks)
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) points ready to absorb incoming damage")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .shield(_, amount) = effect else {
            return EffectApplyOutcome(didApply: false)
        }
        let gain = context.applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityID: ability.id, abilityName: ability.name,
            origin: .direct,
        )
        return EffectApplyOutcome(didApply: gain > 0)
    }
}

struct ShieldFromResourceHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome {
        let block: Int
        var payment: ManaPayment?
        switch effect {
        case .convertManaToBlock, .shieldFromMana:
            block = context.mana(of: target)
            if effect == .convertManaToBlock, block > 0 {
                payment = context.payMana(block, for: target)
            }
        case .shieldFromHalfMana:
            block = context.mana(of: target) / 2
        case let .shieldFromGold(goldPerBlock):
            guard goldPerBlock > 0 else {
                return EffectApplyOutcome(didApply: false)
            }
            block = context.gold / goldPerBlock
        default:
            return EffectApplyOutcome(didApply: false)
        }

        guard block > 0 else { return EffectApplyOutcome(didApply: false) }

        let applied = context.applyBlockGain(
            block,
            to: target,
            source: source,
            abilityID: ability.id, abilityName: ability.name,
            origin: .direct,
        )

        if let payment {
            await CombatTriggerEngine.afterSpendMana(payment, in: &context)
        }

        return EffectApplyOutcome(didApply: applied > 0)
    }
}
