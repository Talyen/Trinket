import Foundation
import TrinketCore

public extension AbilityCatalog {
    static let avatarOfJustice = Ability(
        id: "avatar-of-justice", name: "Avatar", tier: .ultimate,
        operations: [
            .damage(DamageComponent(6, keyword: .holy)),
            .effect(TargetedEffect(.nextStrikeDamageKeywordOverride(.holy), target: .actor)),
            .effect(TargetedEffect(.shield(.block, 6), target: .actor)),
        ],
    )

    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        description: "Gain 6 Block\nRestore 6 Health\nDeal Holy damage equal to half your Block",
        operations: [
            .effect(TargetedEffect(.shield(.block, 6), target: .actor)),
            .effect(TargetedEffect(.instantHeal(.health, 6))),
            .damage(DamageComponent(
                0,
                keyword: .holy,
                scaling: .actorBlockFraction(divisor: 2, minimum: 1),
            )),
        ],
    )

    static let blizzard = Ability(
        id: "blizzard", name: "Blizzard", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 6, 1))],
    )

    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .bleed),
            DamageComponent(2, keyword: .poison),
        ],
        hasLeech: true,
    )

    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        description: "Deal 6 Burn damage\nDetonate all enemy Burn",
        damageComponents: [
            DamageComponent(6, keyword: .burn),
        ],
        targetedEffects: [
            TargetedEffect(.detonateDoT(.burn, 1), target: .enemy, condition: .enemyBurning),
        ],
    )

    static let astralArrow = Ability(
        id: "astral-arrow", name: "Astral Arrow", tier: .ultimate,
        description: "Deal 7 Burn, Freeze, or Bleed damage",
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .burn)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .freeze)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .bleed)]),
        ],
    )

    static let earthquake = Ability(
        id: "earthquake", name: "Earthquake", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.stun, 6, 1))],
    )

    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .physical, target: .actor),
            DamageComponent(4, keyword: .burn),
        ],
        targetedEffects: [
            TargetedEffect(.drawCards(1), target: .actor),
        ],
    )

    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        description: "Gain 8 Block\nGain 5 Gold",
        targetedEffects: [
            TargetedEffect(.shield(.block, 8)),
            TargetedEffect(.resourceGain(.gold, 5)),
        ],
    )

    static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        description: "Deal 6 Bleed damage\nDetonate all Bleed",
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.detonateDoT(.bleed, 1), target: .enemy, condition: .enemyBleeding),
        ],
    )

    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        description: "Roll a 12-sided die\nGain that much Mana, Gold, Thorns, or Block",
        outcomeBranches: (1 ... 12).flatMap { amount in
            [
                AbilityOutcomeBranch(targetedEffects: [TargetedEffect(.resourceGain(.mana, amount))]),
                AbilityOutcomeBranch(targetedEffects: [TargetedEffect(.resourceGain(.gold, amount))]),
                AbilityOutcomeBranch(targetedEffects: [TargetedEffect(.thorns(amount))]),
                AbilityOutcomeBranch(targetedEffects: [TargetedEffect(.shield(.block, amount))]),
            ]
        },
    )

    static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        repeatsManaEmpowerment: true,
    )

    static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        description: "Deal 3 Burn damage\nGain 4 Block and Thorns",
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4)),
            TargetedEffect(.thorns(4)),
        ],
    )

    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        description: "Deal 3 Physical damage\nDraw and play 1 card from your ally's deck",
        damageComponents: [DamageComponent(3, keyword: .physical)],
        targetedEffects: [
            TargetedEffect(.drawAndPlayCards(1)),
        ],
    )

    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        description: "Cleanse the ally with the most status effects\nRestore 6 Health",
        targetedEffects: [
            TargetedEffect(.panacea(baseHeal: 6, healPerDebuff: 0)),
        ],
    )

    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.revive(1), target: .defeatedAlly),
        ],
    )

    static let shadowstep = Ability(
        id: "shadowstep", name: "Shadowstep", tier: .ultimate,
        description: "Draw and play 1 card from your deck\nDodge the next attack against you",
        targetedEffects: [
            TargetedEffect(.drawAndPlayCards(1), target: .actor),
            TargetedEffect(.evadeNextHit, target: .actor),
        ],
    )

    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        description: "Deal 6 Holy or Burn damage\nRestore 3 Health to each ally",
        outcomeBranches: [
            AbilityOutcomeBranch(
                damageComponents: [DamageComponent(6, keyword: .holy)],
                targetedEffects: [TargetedEffect(.instantHeal(.health, 3), target: .eachAlly)],
            ),
            AbilityOutcomeBranch(
                damageComponents: [DamageComponent(6, keyword: .burn)],
                targetedEffects: [TargetedEffect(.instantHeal(.health, 3), target: .eachAlly)],
            ),
        ],
    )

    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain 6 Block\nGain Thorns equal to half your Block",
        operations: [
            .effect(TargetedEffect(.shield(.block, 6))),
            .effect(TargetedEffect(.thornsFromBlockFraction(divisor: 2, minimum: 1))),
        ],
    )

    internal static let ultimateAbilities: [Ability] = [
        avatarOfJustice,
        astralArrow,
        blessedAegis,
        blizzard,
        bloodthorn,
        combustion,
        earthquake,
        faustianBargain,
        goldenPlate,
        hemorrhage,
        luckPotion,
        meteor,
        moltenBulwark,
        packTactics,
        panaceaPotion,
        phoenixFeather,
        shadowstep,
        sunburst,
        thornMail,
    ]
}
