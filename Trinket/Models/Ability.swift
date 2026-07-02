import Foundation

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: AbilityTier
    let damageComponents: [DamageComponent]
    let descriptionOverride: String?
    let targetedEffects: [TargetedEffect]

    var effects: [Effect] {
        targetedEffects.map(\.effect)
    }

    init(
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
        self.descriptionOverride = description
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
    }

    init(
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

    var generatedDescription: String {
        AbilityDescriptionFormatter.format(self)
    }

    var directDamage: Int {
        damageComponents
            .filter { $0.target == .abilityTarget }
            .reduce(0) { $0 + $1.amount }
    }

    var damageKeyword: Keyword {
        logDamageKeyword
    }

    var logDamageKeyword: Keyword {
        let targetComponents = damageComponents.filter { $0.target == .abilityTarget }
        let keywords = Set(targetComponents.map(\.keyword))
        if keywords.count == 1, let keyword = keywords.first {
            return keyword
        }
        return targetComponents.first?.keyword ?? .physical
    }

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result = damageComponents.map(\.keyword)
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
        }
        return result
    }

    var summary: String {
        descriptionOverride ?? generatedDescription
    }
}
