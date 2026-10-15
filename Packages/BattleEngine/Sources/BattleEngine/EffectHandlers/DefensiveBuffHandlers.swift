import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeBlockBuff(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = DefensePoolEngine.blockPoints(in: stacks)
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, resource: L10n.summary_defensivebuffhandlers_3067b09ebf61(keyword.nameResource, total))
    }
}

extension EffectApplication {
    func applyShieldFromResource(in context: inout BattleState) async -> EffectApplyOutcome {
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
