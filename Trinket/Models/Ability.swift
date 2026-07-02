import Foundation

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: AbilityTier
    let directDamage: Int
    let damageKeyword: Keyword
    let description: String
    let targetedEffects: [TargetedEffect]

    var effects: [Effect] {
        targetedEffects.map(\.effect)
    }

    init(
        id: String,
        name: String,
        tier: AbilityTier,
        directDamage: Int,
        damageKeyword: Keyword = .physical,
        description: String,
        effects: [Effect] = [],
        targetedEffects: [TargetedEffect]? = nil
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.directDamage = directDamage
        self.damageKeyword = damageKeyword
        self.description = description
        if let targetedEffects {
            self.targetedEffects = targetedEffects
        } else {
            self.targetedEffects = effects.map { TargetedEffect($0) }
        }
    }

    var damage: Int {
        directDamage
    }

    var damageType: Keyword {
        damageKeyword
    }

    var keywords: [Keyword] {
        var result: [Keyword] = []
        if directDamage > 0 {
            result.append(damageKeyword)
        }
        for targetedEffect in targetedEffects {
            result.append(targetedEffect.effect.keyword)
        }
        return result
    }

    var summary: String {
        description
    }
}
