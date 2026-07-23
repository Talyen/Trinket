import Foundation
import TrinketCore

enum AbilityBuilder {
    static func directHit(
        id: String,
        name: String,
        tier: AbilityTier,
        amount: Int,
        keyword: Keyword = .physical,
        description: String? = nil,
        extras: [TargetedEffect] = [],
        hasLeech: Bool = false
    ) -> Ability {
        let damageComponents = (amount > 0 && keyword != .bleed) ? [DamageComponent(amount, keyword: keyword)] : []
        var targetedEffects = extras
        if let dot = Effect.pairedDoT(keyword: keyword, potency: amount) {
            targetedEffects.insert(TargetedEffect(dot), at: 0)
        }
        return Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            damageComponents: damageComponents,
            targetedEffects: targetedEffects,
            hasLeech: hasLeech
        )
    }

    static func buffOnly(
        id: String,
        name: String,
        tier: AbilityTier,
        effects: [Effect],
        description: String? = nil,
        hasLeech: Bool = false
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            targetedEffects: effects.map { TargetedEffect($0) },
            hasLeech: hasLeech
        )
    }

    static func multiDamage(
        id: String,
        name: String,
        tier: AbilityTier,
        damageComponents: [DamageComponent],
        effects: [TargetedEffect] = [],
        description: String? = nil,
        hasLeech: Bool = false
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: tier,
            description: description,
            damageComponents: damageComponents,
            targetedEffects: effects,
            hasLeech: hasLeech
        )
    }
}
