import Foundation
import TrinketCore

enum AbilityCatalogBasic {
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))],
    )

    static let bash = AbilityBuilder.directHit(
        id: "bash", name: "Bash", tier: .basic,
        amount: 2, keyword: .stun,
    )

    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        damageComponents: [DamageComponent(2, keyword: .stun)],
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2), condition: .enemyStunned),
        ],
    )

    static let block = AbilityBuilder.buffOnly(
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

    static let fangs = AbilityBuilder.directHit(
        id: "fangs", name: "Fangs", tier: .basic,
        amount: 1, keyword: .bleed,
        hasLeech: true,
    )

    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [
            DamageComponent(1, keyword: .burn, bonusAmount: 1, condition: .enemyBurning),
        ],
    )

    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        description: "Deal 2 Freeze damage. If this Freezes the enemy, deal 2 Physical damage.",
        damageComponents: [
            DamageComponent(2, keyword: .freeze),
            DamageComponent(2, keyword: .physical, condition: .enemyFrozen),
        ],
    )

    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic,
        description: "Deal 1 Burn damage. Your next Burn card deals +1 Burn damage.",
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.nextBurnBonus(1), target: .actor)],
    )

    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 2))],
    )

    static let maul = Ability(
        id: "maul", name: "Maul", tier: .basic,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .stun)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .bleed)]),
        ],
    )

    static let pixieDust = Ability(
        id: "pixie-dust", name: "Pixie Dust", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 1, 2))],
    )

    static let rendingSlash = AbilityBuilder.directHit(
        id: "rending-slash", name: "Rend", tier: .basic,
        amount: 2, keyword: .bleed,
    )

    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.shield(.block, 1))],
    )

    static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic,
        description: "Deal 2 to 3 Physical damage.",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .physical)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .physical)]),
        ],
    )

    static let sniffOut = Ability(
        id: "sniff-out", name: "Sniff Out", tier: .basic,
        targetedEffects: [TargetedEffect(.marked(3, 6))],
    )

    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic,
        description: "Deal 2 Physical damage with a +25% chance to Critically Hit.",
        damageComponents: [DamageComponent(2, keyword: .physical)],
        criticalChanceBonus: 0.25,
    )

    static let stargaze = Ability(
        id: "stargaze", name: "Stargaze", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: [TargetedEffect(.resourceGain(.mana, 1))],
    )

    static let venomArrow = AbilityBuilder.directHit(
        id: "venom-arrow", name: "Venom Arrow", tier: .basic,
        amount: 2, keyword: .poison,
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
