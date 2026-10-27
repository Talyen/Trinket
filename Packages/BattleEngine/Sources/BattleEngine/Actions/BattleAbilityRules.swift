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
        guard let branches = selected.outcomeBranches else {
            return Outcomes(ability: selected, branches: [AbilityOutcomeBranch(operations: selected.operations)])
        }
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

    static func canPayBlockCost(_ ability: Ability, actor: Combatant, in context: BattleState) -> Bool {
        canPayBlockCost(ability, action: BattleActionContext(actor: actor, in: context), in: context)
    }

    static func canPayBlockCost(_ ability: Ability, action: BattleActionContext, in context: BattleState) -> Bool {
        // Random branches change operations, not Block cost. Only conditional
        // outcomes need selection before quoting this payment.
        let cost = ability.conditionalOutcome == nil
            ? ability.blockCost
            : possibleOutcomes(ability, action: action, in: context).ability.blockCost
        guard cost > 0 else { return true }
        let balance = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: action.actor))
        return balance >= cost
    }

    static func canPayHealthCost(_ ability: Ability, action: BattleActionContext, in context: BattleState) -> Bool {
        let health = context.roster.health(for: action.actor)
        guard health > 0 else { return false }
        // Ordinary cards quote their ordered operations without constructing an outcome.
        // Conditional and random cards retain the shared selection and fallback rules.
        if ability.conditionalOutcome == nil, ability.outcomeBranches == nil {
            return health > healthCost(ability.operations, action: action, in: context)
        }
        let outcomes = possibleOutcomes(ability, action: action, in: context)
        return outcomes.branches.allSatisfy { health > healthCost($0.operations, action: action, in: context) }
    }

    static func healthCost(_ operations: [AbilityOperation], action: BattleActionContext, in context: BattleState) -> Int {
        let attacks = action.actor.role == .enemy && operations.contains { operation in
            switch operation {
            case let .damage(component):
                component.target != .actor && component.hasPotentialDamage
                    && BattleDamageRules.isEnabled(component, action: action, in: context)
            case .effect: operation.damageKeyword != nil
            }
        }
        let attackCost = attacks ? max(0, context.enemyModifiers.triggers.attackHealthCost) : 0
        return operations.reduce(attackCost) { total, operation in
            guard case let .damage(component) = operation,
                  action.target(component.target, in: context).id == action.actor.id,
                  let amount = BattleDamageRules.amount(component, action: action, in: context) else { return total }
            return SaturatedArithmetic.saturatingAdd(total, max(0, amount))
        }
    }

    static func preparationRecipient(for actor: Combatant, in context: BattleState) -> Combatant {
        guard let owner = context.roster.participant(for: actor), owner.isPartyMember else { return actor }
        let partner = context.roster[owner == .hero ? .companion : .hero]
        return partner.isAlive ? partner.combatant : actor
    }
}
