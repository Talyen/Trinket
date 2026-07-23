import Foundation
import TrinketCore

/// One randomly chosen outcome for an ability that lists alternatives with "or".
public struct AbilityOutcomeBranch: Hashable, Sendable {
    public let damageComponents: [DamageComponent]
    public let targetedEffects: [TargetedEffect]
    /// When true, each damage component's keyword is replaced with a random damage type at play.
    public let randomizeDamageKeywords: Bool

    public init(
        damageComponents: [DamageComponent] = [],
        targetedEffects: [TargetedEffect]? = nil,
        effects: [Effect] = [],
        randomizeDamageKeywords: Bool = false
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
    public let manaCost: Int
    public let criticalChanceBonus: Double
    public let guaranteedCriticalIfEnemyBuffed: Bool
    /// When true, damage from this ability heals the attacker for `Effect.abilityLeechPercent`
    /// of health lost (Leech keyword — not a lasting buff).
    public let hasLeech: Bool

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
        manaCost: Int = 0,
        criticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        hasLeech: Bool = false
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.damageComponents = damageComponents
        descriptionOverride = description
        self.outcomeBranches = outcomeBranches
        self.manaCost = manaCost
        self.criticalChanceBonus = criticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        self.hasLeech = hasLeech
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
        manaCost: Int = 0,
        criticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        hasLeech: Bool = false
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
            manaCost: manaCost,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            hasLeech: hasLeech
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
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
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
        return result
    }

    public var summary: String {
        descriptionOverride ?? generatedDescription
    }

    /// Fixed playable snapshot after choosing a random outcome branch (if any).
    public func resolvingOutcomeBranch(
        using rng: inout some RandomNumberGenerator
    ) -> Ability {
        guard let branches = outcomeBranches, !branches.isEmpty else {
            return self
        }
        let index = Int.random(in: 0 ..< branches.count, using: &rng)
        let branch = branches[index]
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
                    condition: component.condition
                )
            }
        }
        var effects = branch.targetedEffects
        for component in components {
            if let dot = Effect.pairedDoT(keyword: component.keyword, potency: component.amount),
               !effects.contains(where: { $0.effect == dot }) {
                effects.insert(TargetedEffect(dot), at: 0)
            }
        }
        return Ability(
            id: id,
            name: name,
            tier: tier,
            description: descriptionOverride,
            damageComponents: components,
            targetedEffects: effects,
            outcomeBranches: nil,
            manaCost: manaCost,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            hasLeech: hasLeech
        )
    }

    /// True when this resolved ability has Burn/Freeze damage numbers Mana can empower.
    public var hasManaEmpowerableBurnOrFreezeDamage: Bool {
        damageComponents.contains(where: \.isManaEmpowerableBurnOrFreezeDamage)
            || targetedEffects.contains(where: \.effect.isManaEmpowerableBurnOrFreezeDamage)
    }

    /// Snapshot with every Burn/Freeze damage number raised by `amount` (default 1).
    public func empoweredByMana(amount: Int = 1) -> Ability {
        guard amount > 0, hasManaEmpowerableBurnOrFreezeDamage else { return self }
        return Ability(
            id: id,
            name: name,
            tier: tier,
            description: descriptionOverride,
            damageComponents: damageComponents.map { $0.withManaEmpowerment(amount) },
            targetedEffects: targetedEffects.map { targeted in
                TargetedEffect(
                    targeted.effect.withManaEmpowerment(amount),
                    target: targeted.target,
                    condition: targeted.condition
                )
            },
            outcomeBranches: nil,
            manaCost: manaCost,
            criticalChanceBonus: criticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            hasLeech: hasLeech
        )
    }
}
