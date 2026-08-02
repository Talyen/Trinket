import Foundation
import TrinketCore

enum AbilityCatalogBasic {
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 2))]
    )

    static let bash = AbilityBuilder.directHit(
        id: "bash", name: "Bash", tier: .basic,
        amount: 2, keyword: .stun
    )

    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .stun)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 2)]),
        ]
    )

    static let block = AbilityBuilder.buffOnly(
        id: "block", name: "Block", tier: .basic,
        effects: [.shield(.block, 3)]
    )

    static let causticJab = Ability(
        id: "caustic-jab", name: "Caustic Jab", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(1))]
    )

    static let fangs = AbilityBuilder.directHit(
        id: "fangs", name: "Fangs", tier: .basic,
        amount: 1, keyword: .bleed,
        hasLeech: true
    )

    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(1)),
            TargetedEffect(.burn(1), condition: .enemyBurning),
        ]
    )

    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .freeze)]
    )

    static let kindling = AbilityBuilder.directHit(
        id: "kindling", name: "Kindling", tier: .basic,
        amount: 1, keyword: .burn
    )

    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 2))]
    )

    static let maul = Ability(
        id: "maul", name: "Maul", tier: .basic,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .stun)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .bleed)]),
        ]
    )

    static let pixieDust = Ability(
        id: "pixie-dust", name: "Pixie Dust", tier: .basic,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .burn)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.mana, 2)]),
        ]
    )

    static let rayOfFrost = AbilityBuilder.directHit(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        amount: 2, keyword: .freeze
    )

    static let rendingSlash = AbilityBuilder.directHit(
        id: "rending-slash", name: "Rend", tier: .basic,
        amount: 2, keyword: .bleed
    )

    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.shield(.block, 1))]
    )

    static let slash = AbilityBuilder.directHit(
        id: "slash", name: "Slash", tier: .basic,
        amount: 2, keyword: .physical
    )

    static let sniffOut = Ability(
        id: "sniff-out", name: "Sniff Out", tier: .basic,
        targetedEffects: [TargetedEffect(.marked(3, 6))]
    )

    static let stab = AbilityBuilder.directHit(
        id: "stab", name: "Stab", tier: .basic,
        amount: 2, keyword: .physical
    )

    static let stargaze = Ability(
        id: "stargaze", name: "Stargaze", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))]
    )

    static let venomArrow = AbilityBuilder.directHit(
        id: "venom-arrow", name: "Venom Arrow", tier: .basic,
        amount: 1, keyword: .poison
    )

    static let all: [Ability] = [
        apple,
        bash,
        blackjack,
        block,
        causticJab,
        fangs,
        fireArrow,
        iceShot,
        kindling,
        manaBerries,
        maul,
        pixieDust,
        rayOfFrost,
        rendingSlash,
        shieldBash,
        slash,
        sniffOut,
        stab,
        stargaze,
        venomArrow,
    ]
}
