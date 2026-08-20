import Foundation
import TrinketCore

enum AbilityCatalogUltimate {
    static let avatarOfJustice = Ability(
        id: "avatar-of-justice", name: "Avatar", tier: .ultimate,
        description: "Gain 4 Block and deal 6 Holy damage each turn for 2 turns.",
        targetedEffects: [
            TargetedEffect(.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1)),
        ]
    )

    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        description: "Gain 6 Block. Next time you're hit, Deal 6 Holy damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 6)),
            TargetedEffect(.onHitDamage(.holy, 6)),
        ]
    )

    static let blizzard = Ability(
        id: "blizzard", name: "Blizzard", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 4, 2))]
    )

    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .bleed)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .poison)]),
        ],
        hasLeech: true
    )

    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        description: "Deal 4 Burn damage. Doubled if the enemy was already Burning.",
        damageComponents: [
            DamageComponent(4, keyword: .burn, bonusAmount: 4, condition: .enemyBurning),
        ],
        targetedEffects: [
            TargetedEffect(.burn(4), condition: .enemyBurning),
            TargetedEffect(.burn(4)),
        ]
    )

    static let astralArrow = Ability(
        id: "astral-arrow", name: "Astral Arrow", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .stun)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .freeze)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(7, keyword: .burn)]),
        ]
    )

    static let earthquake = Ability(
        id: "earthquake", name: "Earthquake", tier: .ultimate,
        description: "Deal 4 Stun damage each turn for 2 turns.",
        targetedEffects: [TargetedEffect(.recurringDamage(.stun, 4, 2))]
    )

    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        description: "Lose 2 Health. Deal 4 Burn damage. Draw a card.",
        damageComponents: [
            DamageComponent(2, keyword: .physical, target: .actor),
            DamageComponent(4, keyword: .burn),
        ],
        targetedEffects: [
            TargetedEffect(.burn(4)),
            TargetedEffect(.drawCards(1), target: .actor),
        ]
    )

    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        description: "Gain 3 Block, Gold, and Thorns. Your Hero and Companion each dodge the next attack.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 3)),
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.thorns(3)),
            TargetedEffect(.evadeNextHit, target: .hero),
            TargetedEffect(.evadeNextHit, target: .companion),
        ]
    )

    static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        description: "Deal 4 Bleed damage. The next time the enemy attacks, they take 4 Bleed damage.",
        damageComponents: [DamageComponent(4, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.bleed(4)),
            TargetedEffect(.onHitDamage(.bleed, 4), target: .hero),
            TargetedEffect(.onHitDamage(.bleed, 4), target: .companion),
        ]
    )

    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(effects: [.resourceGain(.mana, 7)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 7)]),
            AbilityOutcomeBranch(effects: [.shield(.block, 7)]),
        ]
    )

    static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate,
        description: "Deal 6 Burn damage. Convert all your Mana into bonus Burn damage.",
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(6))]
    )

    static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        description: "Deal 2 Burn damage and Gain 4 Block. Next time you're hit, Deal 3 Burn damage.",
        damageComponents: [DamageComponent(2, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(2)),
            TargetedEffect(.shield(.block, 4)),
            TargetedEffect(.onHitDamage(.burn, 3)),
        ]
    )

    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.drawAndPlayCards(2)),
        ]
    )

    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        description: "Cleanse all debuffs. Restore 1 Health for each debuff cleansed.",
        targetedEffects: [TargetedEffect(.cleanseHealPerDebuff(1))]
    )

    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        description: "Deal 3 Burn damage and Revive an Ally.",
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.revive(1), target: .defeatedAlly),
        ]
    )

    static let shadowstep = Ability(
        id: "shadowstep", name: "Shadowstep", tier: .ultimate,
        description: "Draw a Card. Dodge the next attack. Your next attack is a guaranteed Critical Hit.",
        targetedEffects: [
            TargetedEffect(.drawCards(1), target: .actor),
            TargetedEffect(.evadeNextHit, target: .actor),
            TargetedEffect(.nextStrikeCritical, target: .actor),
        ]
    )

    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        description: "Deal 6 Holy damage and Restore 6 Health.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 6), target: .lowestHealthAlly)]
    )

    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain 5 Block and 5 Thorns.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 5)),
            TargetedEffect(.thorns(5)),
        ]
    )

    static let all: [Ability] = [
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
