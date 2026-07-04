import Foundation
import TrinketCore

public enum AbilityCatalogBasic {
    public static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .lowestHealthAlly)]
    )
    public static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage and steal 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    public static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .physical)],
        targetedEffects: [
            TargetedEffect(.marked(2, 6)),
            TargetedEffect(.resourceGain(.gold, 1), condition: .enemyLowerHealthThanActor)
        ]
    )
    public static let causticJab = Ability(
        id: "caustic-jab", name: "Caustic Jab", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(1))]
    )
    public static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(1)),
            TargetedEffect(.burn(1), condition: .enemyBurning)
        ]
    )
    public static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .freeze)]
    )
    public static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))]
    )
    public static let manaCrystals = Ability(
        id: "mana-crystals", name: "Mana Crystals", tier: .basic,
        targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1)),
            TargetedEffect(.shield(.block, 1, 6))
        ]
    )
    public static let pixieDust = Ability(
        id: "pixie-dust", name: "Pixie Dust", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))]
    )
    public static let rendingSlash = Ability(
        id: "rending-slash", name: "Rending Slash", tier: .basic,
        damageComponents: [
            DamageComponent(1, keyword: .physical, bonusAmount: 1, condition: .enemyBleeding)
        ]
    )
    public static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    public static let sniffOut = Ability(
        id: "sniff-out", name: "Sniff Out", tier: .basic,
        targetedEffects: [TargetedEffect(.marked(2, 6))]
    )
    public static let stargaze = Ability(
        id: "stargaze", name: "Stargaze", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))]
    )
    public static let wiseFrost = Ability(
        id: "wise-frost", name: "Wise Frost", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .lowestHealthAlly)]
    )

    public static let all: [Ability] = [
        apple,
        blackjack,
        bountyShot,
        causticJab,
        fireArrow,
        iceShot,
        manaBerries,
        manaCrystals,
        pixieDust,
        rendingSlash,
        shieldBash,
        sniffOut,
        stargaze,
        wiseFrost
    ] + AbilityCatalogBasicGenerated.all
}
