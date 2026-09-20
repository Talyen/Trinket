import TrinketCore

public enum AbilityOperation: Hashable, Sendable {
    case damage(DamageComponent)
    case effect(TargetedEffect)

    var damageComponent: DamageComponent? {
        if case let .damage(component) = self {
            component
        } else {
            nil
        }
    }

    var targetedEffect: TargetedEffect? {
        if case let .effect(targeted) = self {
            targeted
        } else {
            nil
        }
    }

    public var target: EffectTarget {
        switch self {
        case let .damage(component): component.target
        case let .effect(targeted): targeted.target
        }
    }

    public var condition: DamageCondition? {
        switch self {
        case let .damage(component): component.condition
        case let .effect(targeted): targeted.condition
        }
    }

    public var keyword: Keyword {
        switch self {
        case let .damage(component): component.keyword
        case let .effect(targeted): targeted.effect.keyword
        }
    }

    public var damageKeyword: Keyword? {
        switch self {
        case let .damage(component):
            component.target != .actor && component.amount + component.bonusAmount > 0 ? component.keyword : nil
        case let .effect(targeted):
            targeted.effect.damageKeywordWhenActive
        }
    }

    public var isManaEmpowerable: Bool {
        switch self {
        case let .damage(component): component.isManaEmpowerableBurnOrFreezeDamage
        case let .effect(targeted): targeted.effect.isManaEmpowerableBurnOrFreezeDamage
        }
    }

    public func empowered(by amount: Int) -> Self {
        switch self {
        case let .damage(component):
            .damage(component.withManaEmpowerment(amount))
        case let .effect(targeted):
            .effect(TargetedEffect(
                targeted.effect.withManaEmpowerment(amount), target: targeted.target, condition: targeted.condition,
            ))
        }
    }
}

public extension Ability {
    var possibleOperations: [AbilityOperation] {
        if let outcomeBranches {
            return outcomeBranches.flatMap(\.operations)
        }
        return operations + (conditionalOutcome?.operations ?? [])
    }

    func replacingOperations(_ operations: [AbilityOperation], blockCost: Int? = nil, resolveCondition: Bool = false) -> Self {
        Self(
            id: id, name: name, tier: tier, description: descriptionOverride,
            outcomeBranches: outcomeBranches, criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed, hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment, stealsGold: stealsGold,
            operations: operations, conditionalOutcome: resolveCondition ? nil : conditionalOutcome,
            blockCost: blockCost ?? self.blockCost, guaranteedCriticalCondition: guaranteedCriticalCondition,
        )
    }
}

public struct AbilityConditionalOutcome: Hashable, Sendable {
    public let condition: DamageCondition
    public let operations: [AbilityOperation]
    public let blockCost: Int
    public let contributesToIdentity: Bool

    public init(
        condition: DamageCondition, operations: [AbilityOperation], blockCost: Int = 0,
        contributesToIdentity: Bool = true,
    ) {
        self.condition = condition
        self.operations = operations
        self.blockCost = blockCost
        self.contributesToIdentity = contributesToIdentity
    }
}
