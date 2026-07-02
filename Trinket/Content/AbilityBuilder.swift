import Foundation

enum AbilityBuilder {
    static func directHit(
        id: String,
        name: String,
        tier: AbilityTier,
        amount: Int,
        keyword: Keyword = .physical,
        description: String? = nil,
        extras: [TargetedEffect] = []
    ) -> Ability {
        let damageComponents = amount > 0 ? [DamageComponent(amount, keyword: keyword)] : []
        var targetedEffects = extras
        if let dot = pairedDoT(keyword: keyword, potency: amount) {
            targetedEffects.insert(TargetedEffect(dot), at: 0)
        }
        return Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            damageComponents: damageComponents,
            targetedEffects: targetedEffects
        )
    }

    static func buffOnly(
        id: String,
        name: String,
        tier: AbilityTier,
        effects: [Effect],
        description: String? = nil
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            targetedEffects: effects.map { TargetedEffect($0) }
        )
    }

    static func multiDamage(
        id: String,
        name: String,
        tier: AbilityTier,
        damageComponents: [DamageComponent],
        effects: [TargetedEffect] = [],
        description: String? = nil
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            damageComponents: damageComponents,
            targetedEffects: effects
        )
    }

    private static func pairedDoT(keyword: Keyword, potency: Int) -> Effect? {
        guard potency > 0 else { return nil }
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        case .bleed: return .bleed(potency)
        default: return nil
        }
    }
}
