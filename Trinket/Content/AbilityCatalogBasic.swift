import Foundation

enum AbilityCatalogBasic {
    static let anvil = Ability(
        id: "anvil", name: "Anvil", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: []
    )

    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )

    static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: []
    )

    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        description: "Deal 1 Stun damage.\nGain 1 Gold.",
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let block = Ability(
        id: "block", name: "Block", tier: .basic,
        targetedEffects: [TargetedEffect(.shield(.block, 2, 6))]
    )

    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .basic,
        damageComponents: [DamageComponent(1)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let bread = Ability(
        id: "bread", name: "Bread", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )

    static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(1))]
    )

    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(1))]
    )

    static let gamblersShot = Ability(
        id: "gamblers-shot", name: "Gambler's Shot", tier: .basic,
        damageComponents: [DamageComponent(1)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let gold = Ability(
        id: "gold", name: "Gold", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: []
    )

    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(1))]
    )

    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let manaCrystals = Ability(
        id: "mana-crystals", name: "Mana Crystals", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )

    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: []
    )

    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )

    static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic,
        damageComponents: [DamageComponent(1)]
    )

    static let smellingSalts = Ability(
        id: "smelling-salts", name: "Smelling Salts", tier: .basic,
        targetedEffects: [
            TargetedEffect(.cleanse(.stun)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )

    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic,
        damageComponents: [DamageComponent(1)]
    )

    static let all: [Ability] = [
        anvil,
        apple,
        bash,
        blackjack,
        block,
        bountyShot,
        bread,
        fangs,
        fireArrow,
        gamblersShot,
        gold,
        iceShot,
        kindling,
        manaBerries,
        manaCrystals,
        rayOfFrost,
        shieldBash,
        slash,
        smellingSalts,
        stab
    ]
}
