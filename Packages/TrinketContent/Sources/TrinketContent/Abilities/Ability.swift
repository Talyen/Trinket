import Foundation
import TrinketCore

public struct AbilityOutcomeBranch: Hashable, Sendable {
    public let damageComponents: [DamageComponent]
    public let targetedEffects: [TargetedEffect]
    public let randomizeDamageKeywords: Bool

    public init(
        damageComponents: [DamageComponent] = [],
        targetedEffects: [TargetedEffect]? = nil,
        effects: [Effect] = [],
        randomizeDamageKeywords: Bool = false,
    ) {
        self.damageComponents = damageComponents
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
        self.randomizeDamageKeywords = randomizeDamageKeywords
    }
}

public struct Ability: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tier: AbilityTier
    public let damageComponents: [DamageComponent]
    public let descriptionOverride: String?
    public let targetedEffects: [TargetedEffect]
    public let outcomeBranches: [AbilityOutcomeBranch]?
    public let criticalChanceBonus: Double
    public let guaranteedCriticalIfEnemyBuffed: Bool
    public let hasLeech: Bool
    public let repeatsManaEmpowerment: Bool
    public let stealsGold: Bool

    public var effects: [Effect] {
        targetedEffects.map(\.effect)
    }

    public init(
        id: String,
        name: String,
        tier: AbilityTier,
        description: String? = nil,
        damageComponents: [DamageComponent] = [],
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil,
        outcomeBranches: [AbilityOutcomeBranch]? = nil,
        criticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        hasLeech: Bool = false,
        repeatsManaEmpowerment: Bool = false,
        stealsGold: Bool = false,
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.damageComponents = damageComponents
        descriptionOverride = description
        self.outcomeBranches = outcomeBranches
        self.criticalChanceBonus = criticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        self.hasLeech = hasLeech
        self.repeatsManaEmpowerment = repeatsManaEmpowerment
        self.stealsGold = stealsGold
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
    }

    public init(
        id: String,
        name: String,
        tier: AbilityTier,
        directDamage: Int,
        damageKeyword: Keyword = .physical,
        description: String? = nil,
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil,
        outcomeBranches: [AbilityOutcomeBranch]? = nil,
        criticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        hasLeech: Bool = false,
        repeatsManaEmpowerment: Bool = false,
        stealsGold: Bool = false,
    ) {
        let components = directDamage > 0
            ? [DamageComponent(directDamage, keyword: damageKeyword)]
            : []
        self.init(
            id: id,
            name: name,
            tier: tier,
            description: description,
            damageComponents: components,
            effects: effects,
            targetedEffects: targetedEffects,
            outcomeBranches: outcomeBranches,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment,
            stealsGold: stealsGold,
        )
    }

    public var generatedDescription: String {
        AbilityDescriptionFormatter.format(self)
    }

    public var directDamage: Int {
        damageComponents
            .filter { $0.target == .abilityTarget }
            .reduce(0) { $0 + $1.amount }
    }

    public var damageKeyword: Keyword {
        logDamageKeyword
    }

    public var logDamageKeyword: Keyword {
        let targetComponents = damageComponents.filter { $0.target == .abilityTarget }
        let keywords = Set(targetComponents.map(\.keyword))
        if keywords.count == 1, let keyword = keywords.first {
            return keyword
        }
        return targetComponents.first?.keyword ?? .physical
    }

    public var damage: Int {
        directDamage
    }

    public var damageType: Keyword {
        damageKeyword
    }

    public var keywords: [Keyword] {
        var result = damageComponents.map(\.keyword)
        appendNonDamageKeywords(to: &result)
        return result
    }

    public var presentationKeywords: [Keyword] {
        var result = keywords
        for keyword in Keyword.referenced(in: summary) where !result.contains(keyword) {
            result.append(keyword)
        }
        return result
    }

    public var identityKeywords: [Keyword] {
        var result = damageComponents
            .filter { $0.condition == nil || $0.bonusAmount > 0 }
            .map(\.keyword)
        appendNonDamageKeywords(to: &result)
        return result
    }

    private func appendNonDamageKeywords(to result: inout [Keyword]) {
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
            if case .blessedAegis = targetedEffect.effect {
                result.append(.block)
            }
        }
        if let branches = outcomeBranches {
            for branch in branches {
                result.append(contentsOf: branch.damageComponents.map(\.keyword))
                result.append(contentsOf: branch.targetedEffects.map(\.effect.keyword))
            }
        }
        if hasLeech {
            result.append(.leech)
        }
    }

    public var summary: String {
        descriptionOverride ?? generatedDescription
    }

    public func resolvingOutcomeBranch(
        using rng: inout some RandomNumberGenerator,
    ) -> Self {
        guard let branches = outcomeBranches, !branches.isEmpty else {
            return self
        }
        let index = Int.random(in: 0 ..< branches.count, using: &rng)
        return resolving(branch: branches[index], using: &rng)
    }

    public func resolving(
        branch: AbilityOutcomeBranch,
        using rng: inout some RandomNumberGenerator,
    ) -> Self {
        var components = branch.damageComponents
        if branch.randomizeDamageKeywords {
            let types = Keyword.damageTypes
            components = components.map { component in
                let keyword = types.randomElement(using: &rng) ?? .physical
                return DamageComponent(
                    component.amount,
                    keyword: keyword,
                    target: component.target,
                    bonusAmount: component.bonusAmount,
                    condition: component.condition,
                )
            }
        }
        let effects = branch.targetedEffects
        return Self(
            id: id,
            name: name,
            tier: tier,
            description: descriptionOverride,
            damageComponents: components,
            targetedEffects: effects,
            outcomeBranches: nil,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment,
            stealsGold: stealsGold,
        )
    }

    public var hasManaEmpowerableBurnOrFreezeDamage: Bool {
        operations.contains(where: \.isManaEmpowerable)
    }

    public var hasManaEmpowerableBurnDamage: Bool {
        operations.contains { $0.keyword == .burn && $0.isManaEmpowerable }
    }

    public func empoweredByMana(amount: Int = 1, includingBothElements: Bool = false) -> Self {
        guard amount > 0, let first = operations.first(where: \.isManaEmpowerable) else { return self }
        var empowered = operations.map { $0.empowered(by: amount) }
        if includingBothElements {
            for keyword in [Keyword.burn, .freeze] where !operations.contains(where: { $0.keyword == keyword && $0.isManaEmpowerable }) {
                empowered.append(.damage(DamageComponent(amount, keyword: keyword, target: first.target, condition: first.condition)))
            }
        }
        return replacingOperations(empowered)
    }

    public var dealsCombatDamage: Bool {
        possibleOperations.contains { $0.damageKeyword != nil }
    }
}
