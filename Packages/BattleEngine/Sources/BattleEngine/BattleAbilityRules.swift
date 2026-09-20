import TrinketContent
import TrinketCore

enum BattleAbilityRules {
    static func canPayHealthCost(_ ability: Ability, actor: Combatant, in context: BattleState) -> Bool {
        let componentSets = ability.outcomeBranches?.map(\.damageComponents) ?? [ability.damageComponents]
        let cost = componentSets.map { healthCost($0, actor: actor, in: context) }.max() ?? 0
        return context.roster.health(for: actor) > cost
    }

    static func healthCost(_ components: [DamageComponent], actor: Combatant, in context: BattleState) -> Int {
        let abilityTarget = BattleTargetResolver.abilityTarget(for: actor, in: context)
        return components.reduce(0) { total, component in
            let target = BattleTargetResolver.effectTarget(
                component.target, actor: actor, abilityTarget: abilityTarget, in: context,
            )
            guard target.id == actor.id else { return total }
            var amount = component.amount
            if let condition = component.condition {
                if BattleConditionEvaluator.isMet(condition, actor: actor, in: context) {
                    amount += component.bonusAmount
                } else if component.bonusAmount == 0 {
                    return total
                }
            }
            return total + max(0, amount)
        }
    }

    static func resolveConditionalOutcome(_ ability: Ability, actor: Combatant, in context: BattleState) -> Ability {
        guard let conditional = ability.conditionalOutcome else { return ability }
        let selected = BattleConditionEvaluator.isMet(conditional.condition, actor: actor, in: context)
        return ability.replacingOperations(
            selected ? conditional.operations : ability.operations,
            blockCost: selected ? conditional.blockCost : ability.blockCost,
            resolveCondition: true,
        )
    }

    static func preparationRecipient(for actor: Combatant, in context: BattleState) -> Combatant {
        BattleActionContext(actor: actor, in: context).allies(in: context)
            .first { $0.id != actor.id && context.health(of: $0) > 0 } ?? actor
    }

    static func resolveOutcome(_ ability: Ability, actor: Combatant, in context: inout BattleState) -> Ability {
        let ability = resolveConditionalOutcome(ability, actor: actor, in: context)
        guard let branches = ability.outcomeBranches else { return ability }
        guard let selected = branches.randomElement(using: &context.rng) else { return ability }
        let operations = selected.operations.compactMap { operation -> AbilityOperation? in
            guard case let .effect(targeted) = operation else { return operation }
            if let condition = targeted.condition,
               !BattleConditionEvaluator.isMet(condition, actor: actor, in: context) {
                return nil
            }
            return .effect(TargetedEffect(targeted.effect, target: targeted.target))
        }
        let branch = AbilityOutcomeBranch(
            randomizeDamageKeywords: selected.randomizeDamageKeywords,
            operations: operations,
        )
        return ability.resolving(branch: branch, using: &context.rng)
    }
}
