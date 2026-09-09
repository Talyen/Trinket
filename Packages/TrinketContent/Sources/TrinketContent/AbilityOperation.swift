import TrinketCore

public enum AbilityOperation: Hashable, Sendable {
    case damage(DamageComponent)
    case effect(TargetedEffect)

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
            switch targeted.effect {
            case .burn, .poison, .bleed, .recurringDamage, .avatar:
                (targeted.effect.potency ?? 0) > 0 ? targeted.effect.keyword : nil
            case let .multiplyDoT(keyword, multiplier):
                multiplier > 1 ? keyword : nil
            case let .detonateDoT(keyword, amount):
                amount > 0 ? keyword : nil
            default:
                nil
            }
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
    var operations: [AbilityOperation] {
        damageComponents.map(AbilityOperation.damage) + targetedEffects.map(AbilityOperation.effect)
    }

    var possibleOperations: [AbilityOperation] {
        guard let outcomeBranches else { return operations }
        return outcomeBranches.flatMap(\.operations)
    }

    func replacingOperations(_ operations: [AbilityOperation]) -> Self {
        Self(
            id: id, name: name, tier: tier, description: descriptionOverride,
            damageComponents: operations.compactMap {
                if case let .damage(component) = $0 {
                    component
                } else {
                    nil
                }
            },
            targetedEffects: operations.compactMap {
                if case let .effect(targeted) = $0 {
                    targeted
                } else {
                    nil
                }
            },
            outcomeBranches: outcomeBranches, criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed, hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment, stealsGold: stealsGold,
        )
    }
}

public extension AbilityOutcomeBranch {
    var operations: [AbilityOperation] {
        damageComponents.map(AbilityOperation.damage) + targetedEffects.map(AbilityOperation.effect)
    }
}
