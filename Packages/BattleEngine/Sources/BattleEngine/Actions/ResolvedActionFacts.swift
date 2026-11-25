import TrinketContent
import TrinketCore

final class ResolvedActionFacts: Sendable {
    let action: BattleActionContext
    let origin: DamageOperation.AttackOrigin
    let originalAbility: Ability
    let ability: Ability
    let guaranteedCritical: Bool
    let isRandom: Bool
    let damageKeywords: Set<Keyword>
    let cleanses: Bool
    let targetsOnlyAlly: Bool

    init(
        original: Ability,
        resolved: Ability,
        action: BattleActionContext,
        origin: DamageOperation.AttackOrigin,
        guaranteedCritical: Bool? = nil,
        in context: borrowing BattleState,
    ) {
        self.action = action
        self.origin = origin
        originalAbility = original
        ability = resolved
        self.guaranteedCritical = guaranteedCritical ?? resolved.guaranteedCriticalCondition.map {
            BattleConditionEvaluator.isMet($0, action: action, in: context)
        } ?? false
        isRandom = original.outcomeBranches != nil
        var keywords: Set<Keyword> = []
        var cleanses = false
        var targetsOnlyAlly = context.modifiers(for: action.actor.id).triggers.allySupportCardDodgePercent > 0
        var hasEffect = false
        for operation in resolved.operations {
            switch operation {
            case let .damage(component):
                guard BattleDamageRules.isEnabled(component, action: action, in: context) else { continue }
                if component.hasPotentialDamage {
                    targetsOnlyAlly = false
                    guard component.target != .actor else { continue }
                    keywords.insert(component.keyword)
                }
            case let .effect(targeted):
                if let condition = targeted.condition,
                   !BattleConditionEvaluator.isMet(condition, action: action, in: context) {
                    continue
                }
                hasEffect = true
                if targetsOnlyAlly {
                    let targets = if case .panacea = targeted.effect {
                        [
                            EffectApplication.panaceaCleanseTarget(action: action, in: context),
                            action.target(EffectApplication.panaceaHealTarget, in: context),
                        ]
                    } else {
                        action.targets(targeted.target, in: context)
                    }
                    targetsOnlyAlly = targets.allSatisfy {
                        $0.id != action.actor.id && $0.role != .enemy && context.health(of: $0) > 0
                    }
                }
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
        self.targetsOnlyAlly = hasEffect && targetsOnlyAlly && keywords.isEmpty
    }
}
