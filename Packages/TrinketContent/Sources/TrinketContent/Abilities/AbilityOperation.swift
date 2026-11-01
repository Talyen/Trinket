import TrinketCore

public enum AbilityOperation: Hashable, Sendable {
    case damage(DamageComponent)
    case effect(TargetedEffect)

    public var damageComponent: DamageComponent? {
        if case let .damage(component) = self {
            component
        } else {
            nil
        }
    }

    public var targetedEffect: TargetedEffect? {
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

    /// Keywords contributed by this operation, excluding self costs and draw-only effects.
    public var keywords: [Keyword] {
        keywords(identityOnly: false)
    }

    public func keywords(identityOnly: Bool) -> [Keyword] {
        switch self {
        case let .damage(component):
            guard component.target != .actor else { return [] }
            if identityOnly, component.condition != nil, component.bonusAmount == 0 {
                return []
            }
            return [component.keyword]
        case let .effect(targeted):
            switch targeted.effect {
            case .drawCards, .drawAndPlayCards:
                return []
            case .blessedAegis:
                return [targeted.effect.keyword, .block]
            default:
                return [targeted.effect.keyword]
            }
        }
    }

    public func hasLeech(identityOnly: Bool = false) -> Bool {
        guard case let .damage(component) = self, component.target != .actor else { return false }
        return component.hasLeech && (!identityOnly || component.condition == nil || component.bonusAmount > 0)
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
            component.target != .actor && component.hasPotentialDamage ? component.keyword : nil
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
                chance: targeted.chance,
            ))
        }
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
