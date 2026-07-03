import Foundation
import TrinketCore

public struct Ability: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tier: AbilityTier
    public let damageComponents: [DamageComponent]
    public let descriptionOverride: String?
    public let targetedEffects: [TargetedEffect]

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
        targetedEffects: [TargetedEffect]? = nil
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.damageComponents = damageComponents
        descriptionOverride = description
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
        targetedEffects: [TargetedEffect]? = nil
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
            targetedEffects: targetedEffects
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
        return result
    }

    public var summary: String {
        descriptionOverride ?? generatedDescription
    }
}
