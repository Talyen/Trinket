import TrinketContent
import TrinketCore

/// Evaluates authored component rules at the caller's checkpoint. Amounts are
/// deliberately not cached: earlier operations can change Block and conditions.
enum BattleDamageRules {
    static func isEnabled(_ component: DamageComponent, action: BattleActionContext, in context: borrowing BattleState) -> Bool {
        conditionalBonus(component, action: action, in: context) != nil
    }

    static func amount(_ component: DamageComponent, action: BattleActionContext, in context: borrowing BattleState) -> Int? {
        guard let bonus = conditionalBonus(component, action: action, in: context) else { return nil }
        let base: Int
        switch component.scaling {
        case let .actorBlockFraction(divisor, minimum):
            guard divisor > 0 else { return nil }
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: action.actor))
            base = max(minimum, block / divisor)
        case nil:
            base = component.amount
        }
        return SaturatedArithmetic.saturatingAdd(base, bonus)
    }

    private static func conditionalBonus(
        _ component: DamageComponent, action: BattleActionContext, in context: borrowing BattleState,
    ) -> Int? {
        guard let condition = component.condition else { return 0 }
        if BattleConditionEvaluator.isMet(condition, action: action, in: context) {
            return component.bonusAmount
        }
        return component.bonusAmount == 0 ? nil : 0
    }
}
