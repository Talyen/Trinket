import Foundation
import TrinketCore

public struct AbilityOutcomeBranch: Hashable, Sendable {
    public let condition: DamageCondition?
    public let operations: [AbilityOperation]
    public var damageComponents: [DamageComponent] {
        operations.compactMap(\.damageComponent)
    }

    public var targetedEffects: [TargetedEffect] {
        operations.compactMap(\.targetedEffect)
    }

    public let randomizeDamageKeywords: Bool

    public init(
        damageComponents: [DamageComponent] = [],
        targetedEffects: [TargetedEffect]? = nil,
        effects: [Effect] = [],
        randomizeDamageKeywords: Bool = false,
        operations: [AbilityOperation]? = nil,
        condition: DamageCondition? = nil,
    ) {
        self.condition = condition
        self.operations = Ability.buildOperations(
            damageComponents: damageComponents,
            effects: effects,
            targetedEffects: targetedEffects,
            explicitOperations: operations,
        )
        self.randomizeDamageKeywords = randomizeDamageKeywords
    }
}

public struct Ability: Identifiable, Hashable, Sendable {
    private let storage: AbilityStorage
    public var id: String {
        storage.definition.id
    }

    public var name: String {
        storage.definition.name
    }

    public var tier: AbilityTier {
        storage.definition.tier
    }

    public var operations: [AbilityOperation] {
        storage.definition.operations
    }

    public var damageComponents: [DamageComponent] {
        storage.damageComponents
    }

    public var descriptionOverride: String? {
        storage.definition.descriptionOverride
    }

    public var targetedEffects: [TargetedEffect] {
        storage.targetedEffects
    }

    public var outcomeBranches: [AbilityOutcomeBranch]? {
        storage.definition.outcomeBranches
    }

    public var conditionalOutcome: AbilityConditionalOutcome? {
        storage.definition.conditionalOutcome
    }

    public var blockCost: Int {
        storage.definition.blockCost
    }

    public var guaranteedCriticalCondition: DamageCondition? {
        storage.definition.guaranteedCriticalCondition
    }

    public var criticalChanceBonus: Double {
        storage.definition.criticalChanceBonus
    }

    public var guaranteedCriticalIfEnemyBuffed: Bool {
        storage.definition.guaranteedCriticalIfEnemyBuffed
    }

    /// Card-wide Leech; individual damage components can grant it independently.
    public var hasLeech: Bool {
        storage.definition.hasLeech
    }

    public var repeatsManaEmpowerment: Bool {
        storage.definition.repeatsManaEmpowerment
    }

    public var stealsGold: Bool {
        storage.definition.stealsGold
    }

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
        operations: [AbilityOperation]? = nil,
        conditionalOutcome: AbilityConditionalOutcome? = nil,
        blockCost: Int = 0,
        guaranteedCriticalCondition: DamageCondition? = nil,
    ) {
        self.init(definition: .init(
            id: id, name: name, tier: tier,
            operations: Self.buildOperations(
                damageComponents: damageComponents,
                effects: effects,
                targetedEffects: targetedEffects,
                explicitOperations: operations,
            ),
            descriptionOverride: description,
            outcomeBranches: outcomeBranches, conditionalOutcome: conditionalOutcome,
            blockCost: blockCost, guaranteedCriticalCondition: guaranteedCriticalCondition,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed, hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment, stealsGold: stealsGold,
        ))
    }

    static func buildOperations(
        damageComponents: [DamageComponent],
        effects: [Effect],
        targetedEffects: [TargetedEffect]?,
        explicitOperations: [AbilityOperation]?,
    ) -> [AbilityOperation] {
        if let explicitOperations {
            return explicitOperations
        }
        let effectsList = targetedEffects ?? effects.map { TargetedEffect($0) }
        var result: [AbilityOperation] = []
        result.reserveCapacity(damageComponents.count + effectsList.count)
        for component in damageComponents {
            result.append(.damage(component))
        }
        for effect in effectsList {
            result.append(.effect(effect))
        }
        return result
    }

    private init(definition: AbilityStorage.Definition) {
        storage = AbilityStorage(definition)
    }

    private func updatingDefinition(_ update: (inout AbilityStorage.Definition) -> Void) -> Self {
        var definition = storage.definition
        update(&definition)
        return Self(definition: definition)
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
        storage.generatedDescription(for: self)
    }

    public var directDamage: Int {
        damageComponents.lazy
            .filter { $0.target == .abilityTarget }
            .reduce(0) { SaturatedArithmetic.saturatingAdd($0, $1.amount) }
    }

    public var damageKeyword: Keyword {
        damageComponents
            .first { $0.target == .abilityTarget }?.keyword ?? .physical
    }

    public var keywords: [Keyword] {
        storage.keywords(identityOnly: false) {
            collectKeywords(identityOnly: false)
        }
    }

    public var presentationKeywords: [Keyword] {
        storage.presentationKeywords(for: self)
    }

    public var identityKeywords: [Keyword] {
        storage.keywords(identityOnly: true) {
            collectKeywords(identityOnly: true)
        }
    }

    private func collectKeywords(identityOnly: Bool) -> [Keyword] {
        var result: [Keyword] = []
        for operation in operations where operation.damageComponent != nil {
            result.append(contentsOf: operation.keywords(identityOnly: identityOnly))
        }
        for targetedEffect in targetedEffects {
            result.append(contentsOf: AbilityOperation.effect(targetedEffect).keywords(identityOnly: identityOnly))
        }
        var includesLeech = hasLeech || operations.contains { $0.hasLeech(identityOnly: identityOnly) }
        for branch in outcomeBranches ?? [] {
            for operation in branch.operations where operation.damageComponent != nil {
                result.append(contentsOf: operation.keywords(identityOnly: identityOnly))
            }
            for operation in branch.operations where operation.targetedEffect != nil {
                result.append(contentsOf: operation.keywords(identityOnly: identityOnly))
            }
            includesLeech = includesLeech || branch.operations.contains { $0.hasLeech(identityOnly: identityOnly) }
        }
        if let conditionalOutcome, !identityOnly || conditionalOutcome.contributesToIdentity {
            for operation in conditionalOutcome.operations {
                result.append(contentsOf: operation.keywords(identityOnly: identityOnly))
            }
            includesLeech = includesLeech || conditionalOutcome.operations.contains { $0.hasLeech(identityOnly: identityOnly) }
        }
        if includesLeech {
            result.append(.leech)
        }
        return result
    }

    public var summary: String {
        descriptionOverride ?? generatedDescription
    }

    public func replacingOperations(_ operations: [AbilityOperation], blockCost: Int? = nil, resolveCondition: Bool = false) -> Self {
        updatingDefinition {
            $0.operations = operations
            if let blockCost {
                $0.blockCost = blockCost
            }
            if resolveCondition {
                $0.conditionalOutcome = nil
            }
        }
    }

    public func resolving(
        branch: AbilityOutcomeBranch,
        using rng: inout some RandomNumberGenerator,
    ) -> Self {
        let resolvedOperations = !branch.randomizeDamageKeywords ? branch.operations : branch.operations
            .map { operation -> AbilityOperation in
                guard case let .damage(component) = operation else { return operation }
                return .damage(DamageComponent(
                    component.amount,
                    keyword: Keyword.damageTypes.randomElement(using: &rng) ?? .physical,
                    target: component.target,
                    bonusAmount: component.bonusAmount,
                    condition: component.condition,
                    scaling: component.scaling, hasLeech: component.hasLeech,
                ))
            }
        return updatingDefinition {
            $0.operations = resolvedOperations
            $0.outcomeBranches = nil
            $0.conditionalOutcome = nil
        }
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
        if let outcomeBranches, !outcomeBranches.isEmpty {
            return outcomeBranches.contains { branch in
                branch.operations.contains { $0.damageKeyword != nil }
            }
        }
        return operations.contains { $0.damageKeyword != nil }
            || (conditionalOutcome?.operations.contains { $0.damageKeyword != nil } ?? false)
    }
}
