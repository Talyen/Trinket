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
        self.operations = operations ?? (damageComponents.map(AbilityOperation.damage)
            + (targetedEffects ?? effects.map { TargetedEffect($0) }).map(AbilityOperation.effect))
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
        operations.compactMap(\.damageComponent)
    }

    public var descriptionOverride: String? {
        storage.definition.descriptionOverride
    }

    public var targetedEffects: [TargetedEffect] {
        operations.compactMap(\.targetedEffect)
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
        operations.compactMap { $0.targetedEffect?.effect }
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
            operations: operations ?? (damageComponents.map(AbilityOperation.damage)
                + (targetedEffects ?? effects.map { TargetedEffect($0) }).map(AbilityOperation.effect)),
            descriptionOverride: description,
            outcomeBranches: outcomeBranches, conditionalOutcome: conditionalOutcome,
            blockCost: blockCost, guaranteedCriticalCondition: guaranteedCriticalCondition,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed, hasLeech: hasLeech,
            repeatsManaEmpowerment: repeatsManaEmpowerment, stealsGold: stealsGold,
        ))
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
        operations.lazy.compactMap(\.damageComponent)
            .filter { $0.target == .abilityTarget }
            .reduce(0) { $0 + $1.amount }
    }

    public var damageKeyword: Keyword {
        operations.lazy.compactMap(\.damageComponent)
            .first { $0.target == .abilityTarget }?.keyword ?? .physical
    }

    public var keywords: [Keyword] {
        storage.keywords(identityOnly: false) {
            var result = operations.compactMap { $0.damageComponent?.keyword }
            appendNonDamageKeywords(to: &result)
            return result
        }
    }

    public var presentationKeywords: [Keyword] {
        storage.presentationKeywords(for: self)
    }

    public var identityKeywords: [Keyword] {
        storage.keywords(identityOnly: true) {
            var result = operations.compactMap { operation -> Keyword? in
                guard let component = operation.damageComponent,
                      component.condition == nil || component.bonusAmount > 0 else { return nil }
                return component.keyword
            }
            appendNonDamageKeywords(to: &result, identityOnly: true)
            return result
        }
    }

    private func appendNonDamageKeywords(to result: inout [Keyword], identityOnly: Bool = false) {
        func qualifies(_ effect: Effect) -> Bool {
            switch effect {
            case .drawCards, .drawAndPlayCards:
                false
            default:
                true
            }
        }
        for targetedEffect in operations.lazy.compactMap(\.targetedEffect) {
            guard qualifies(targetedEffect.effect) else { continue }
            result.append(targetedEffect.effect.keyword)
            if case .blessedAegis = targetedEffect.effect {
                result.append(.block)
            }
        }
        if let branches = outcomeBranches {
            for branch in branches {
                result.append(contentsOf: branch.operations.lazy.compactMap(\.damageComponent).map(\.keyword))
                result.append(contentsOf: branch.operations.lazy.compactMap(\.targetedEffect)
                    .map(\.effect)
                    .filter(qualifies)
                    .map(\.keyword))
            }
        }
        if let conditionalOutcome, !identityOnly || conditionalOutcome.contributesToIdentity {
            result.append(contentsOf: conditionalOutcome.operations.lazy.compactMap { op in
                if let effect = op.targetedEffect, !qualifies(effect.effect) {
                    return nil
                }
                return op.keyword
            })
        }
        if hasLeech {
            result.append(.leech)
        }
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
        let resolvedOperations = branch.operations.map { operation -> AbilityOperation in
            guard branch.randomizeDamageKeywords, case let .damage(component) = operation else { return operation }
            return .damage(DamageComponent(
                component.amount,
                keyword: Keyword.damageTypes.randomElement(using: &rng) ?? .physical,
                target: component.target,
                bonusAmount: component.bonusAmount,
                condition: component.condition,
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
        if let outcomeBranches {
            return outcomeBranches.contains { branch in
                branch.operations.contains { $0.damageKeyword != nil }
            }
        }
        return operations.contains { $0.damageKeyword != nil }
            || (conditionalOutcome?.operations.contains { $0.damageKeyword != nil } ?? false)
    }
}
