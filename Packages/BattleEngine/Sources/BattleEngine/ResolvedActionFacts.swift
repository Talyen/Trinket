import TrinketContent
import TrinketCore

final class ResolvedActionFacts: Sendable {
    let action: BattleActionContext
    let origin: DamageOperation.AttackOrigin
    let originalAbility: Ability
    let ability: Ability
    let isRandom: Bool
    let damageKeywords: Set<Keyword>
    let cleanses: Bool

    init(
        original: Ability,
        resolved: Ability,
        action: BattleActionContext,
        origin: DamageOperation.AttackOrigin,
        in context: BattleState,
    ) {
        self.action = action
        self.origin = origin
        originalAbility = original
        ability = resolved
        isRandom = original.outcomeBranches != nil
        var keywords: Set<Keyword> = []
        var cleanses = false
        for operation in resolved.operations {
            let eligible = operation.condition.map { BattleConditionEvaluator.isMet($0, action: action, in: context) } ?? true
            switch operation {
            case let .damage(component):
                guard component.target != .actor else { continue }
                guard eligible || component.bonusAmount > 0 else { continue }
                if component.amount + (eligible ? component.bonusAmount : 0) > 0 {
                    keywords.insert(component.keyword)
                }
            case let .effect(targeted):
                guard eligible else { continue }
                if let keyword = operation.damageKeyword {
                    keywords.insert(keyword)
                }
                switch targeted.effect {
                case .cleanse, .cleanseRandom, .cleanseHealPerDebuff, .panacea: cleanses = true
                default: break
                }
            }
        }
        damageKeywords = keywords
        self.cleanses = cleanses
    }
}
