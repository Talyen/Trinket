import Foundation
import TrinketCore

public extension AbilityCatalog {
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))],
    )

    static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic,
        directDamage: 3, damageKeyword: .stun,
    )

    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .stun)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2), condition: .enemyStunned),
        ],
        stealsGold: true,
    )

    static let block = Ability(
        id: "block", name: "Block", tier: .basic,
        effects: [.shield(.block, 3)],
    )

    static let causticJab = Ability(
        id: "caustic-jab", name: "Caustic Jab", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .poison)],
        targetedEffects: [
            TargetedEffect(.halveShield(.block), target: .enemy),
        ],
    )

    static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic,
        directDamage: 1, damageKeyword: .bleed,
        hasLeech: true,
    )

    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        directDamage: 2, damageKeyword: .burn,
    )

    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        description: "Deal 2 Freeze damage\nDoubled against Frozen enemies",
        damageComponents: [
            DamageComponent(2, keyword: .freeze, bonusAmount: 2, condition: .enemyFrozen),
        ],
    )

    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic,
        description: "Deal 1 Burn damage\nDoubled if enemy was not Burning",
        damageComponents: [
            DamageComponent(1, keyword: .burn, bonusAmount: 1, condition: .enemyNotBurning),
        ],
    )

    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.resourceGain(.mana, 2)),
        ],
    )

    static let maul = Ability(
        id: "maul", name: "Maul", tier: .basic,
        description: "Deal 3 Bleed damage\nDeal Stun instead against enemies with Block",
        damageComponents: [DamageComponent(3, keyword: .bleed)],
        conditionalOutcome: AbilityConditionalOutcome(
            condition: .enemyHasBlock,
            operations: [.damage(DamageComponent(3, keyword: .stun))],
        ),
    )

    static let pixieDust = Ability(
        id: "pixie-dust", name: "Pixie Dust", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        description: "Deal 1 Freeze damage, twice",
        damageComponents: [
            DamageComponent(1, keyword: .freeze),
            DamageComponent(1, keyword: .freeze),
        ],
    )

    static let rendingSlash = Ability(
        id: "rending-slash", name: "Rend", tier: .basic,
        directDamage: 2, damageKeyword: .bleed,
    )

    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        operations: [
            .effect(TargetedEffect(.shield(.block, 1))),
            .damage(DamageComponent(
                0,
                keyword: .stun,
                scaling: .actorBlockFraction(divisor: 2, minimum: 1),
            )),
        ],
    )

    static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic,
        directDamage: 3,
    )

    static let sniffOut = Ability(
        id: "sniff-out", name: "Sniff Out", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.partyDamageBonus(1))],
    )

    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic,
        description: "Deal 2 Physical damage\nCritically Hit enemies at full Health",
        damageComponents: [DamageComponent(2, keyword: .physical)],
        guaranteedCriticalCondition: .enemyFullHealth,
    )

    static let stargaze = Ability(
        id: "stargaze", name: "Stargaze", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .basic,
        directDamage: 2, damageKeyword: .poison,
    )

    internal static let basicAbilities: [Ability] = [
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
