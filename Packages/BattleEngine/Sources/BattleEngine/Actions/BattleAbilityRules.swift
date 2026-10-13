import TrinketContent
import TrinketCore

enum BattleAbilityRules {
    struct Outcomes {
        let ability: Ability
        let branches: [AbilityOutcomeBranch]

        func resolve(using rng: inout some RandomNumberGenerator) -> Ability {
            guard ability.outcomeBranches != nil,
                  let selected = branches.randomElement(using: &rng) else { return ability }
            return ability.resolving(branch: selected, using: &rng)
        }
    }

    static func possibleOutcomes(_ ability: Ability, action: BattleActionContext, in context: BattleState) -> Outcomes {
        let selected: Ability
        if let conditional = ability.conditionalOutcome {
            let matches = BattleConditionEvaluator.isMet(conditional.condition, action: action, in: context)
            selected = ability.replacingOperations(
                matches ? conditional.operations : ability.operations,
                blockCost: matches ? conditional.blockCost : ability.blockCost,
                resolveCondition: true,
            )
        } else {
            selected = ability
        }
        let branches = selected.outcomeBranches ?? [AbilityOutcomeBranch(operations: selected.operations)]
        let eligible = branches.filter { branch in
            branch.condition.map { BattleConditionEvaluator.isMet($0, action: action, in: context) } ?? true
        }
        // Execution's fallback is part of the possible outcome set. Quotes and
        // affordability must include it too, without consuming a random value.
        return Outcomes(ability: selected, branches: eligible.isEmpty ? branches : eligible)
    }

    static func resolveOutcome(_ ability: Ability, actor: Combatant, in context: inout BattleState) -> Ability {
        let action = BattleActionContext(actor: actor, in: context)
        let outcomes = possibleOutcomes(ability, action: action, in: context)
        return outcomes.resolve(using: &context.rng)
    }

    static func canPayHealthCost(_ ability: Ability, actor: Combatant, in context: BattleState) -> Bool {
        canPayHealthCost(ability, action: BattleActionContext(actor: actor, in: context), in: context)
    }

    static func canPayHealthCost(_ ability: Ability, action: BattleActionContext, in context: BattleState) -> Bool {
        let outcomes = possibleOutcomes(ability, action: action, in: context)
        let cost = outcomes.branches.map { healthCost($0.damageComponents, action: action, in: context) }.max() ?? 0
        return context.roster.health(for: action.actor) > cost
    }

    static func healthCost(_ components: [DamageComponent], action: BattleActionContext, in context: BattleState) -> Int {
        components.reduce(0) { total, component in
            guard action.target(component.target, in: context).id == action.actor.id,
                  let amount = BattleDamageRules.amount(component, action: action, in: context) else { return total }
            return SaturatedArithmetic.saturatingAdd(total, max(0, amount))
        }
    }

    static func preparationRecipient(for actor: Combatant, in context: BattleState) -> Combatant {
        BattleActionContext(actor: actor, in: context).allies(in: context)
            .first { $0.id != actor.id && context.health(of: $0) > 0 } ?? actor
    }
}
