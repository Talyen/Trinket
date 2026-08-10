import Foundation
import TrinketCore

enum AbilityCatalogUltimate {
    static let avatarOfJustice = Ability(
        id: "avatar-of-justice", name: "Avatar", tier: .ultimate,
        description: "Deal 6 Holy damage each turn for 2 turns. Gain 6 Block.",
        targetedEffects: [
            TargetedEffect(.recurringDamage(.holy, 6, 1)),
            TargetedEffect(.shield(.block, 6)),
        ]
    )

    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .holy)]),
            AbilityOutcomeBranch(effects: [.shield(.block, 6)]),
        ]
    )

    static let blizzard = Ability(
        id: "blizzard", name: "Blizzard", tier: .ultimate,
        targetedEffects: [TargetedEffect(.recurringDamage(.freeze, 3, 2))]
    )

    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(4, keyword: .bleed)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(3, keyword: .poison)]),
        ]
    )

    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.multiplyDoT(.burn, 2), condition: .enemyBurning),
            TargetedEffect(.burn(2), condition: .enemyNotBurning),
        ]
    )

    static let astralArrow = Ability(
        id: "astral-arrow", name: "Astral Arrow", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .stun)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .freeze)]),
            AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .burn)]),
        ]
    )

    static let earthquake = AbilityBuilder.directHit(
        id: "earthquake", name: "Earthquake", tier: .ultimate,
        amount: 6, keyword: .stun
    )

    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .physical, target: .actor),
            DamageComponent(6, keyword: .burn),
        ],
        targetedEffects: [TargetedEffect(.burn(6))]
    )

    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        targetedEffects: [TargetedEffect(.shieldFromGold(goldPerBlock: 7))]
    )

    static let hemorrhage = AbilityBuilder.directHit(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        amount: 5, keyword: .bleed
    )

    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(effects: [.resourceGain(.mana, 7)]),
            AbilityOutcomeBranch(effects: [.resourceGain(.gold, 7)]),
            AbilityOutcomeBranch(effects: [.shield(.block, 7)]),
        ]
    )

    static let meteor = AbilityBuilder.directHit(
        id: "meteor", name: "Meteor", tier: .ultimate,
        amount: 6, keyword: .burn
    )

    static let moltenBulwark = AbilityBuilder.directHit(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        amount: 4, keyword: .burn,
        extras: [TargetedEffect(.shield(.block, 4))]
    )

    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.drawCards(1), target: .hero),
            TargetedEffect(.drawCards(1), target: .companion),
            TargetedEffect(.instantHeal(.health, 3)),
        ]
    )

    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        targetedEffects: [TargetedEffect(.cleanse(nil))]
    )

    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.revive(3)),
        ]
    )

    static let shadowstep = Ability(
        id: "shadowstep", name: "Shadowstep", tier: .ultimate,
        description: "Your next attack deals double damage. Dodge the next attack.",
        targetedEffects: [
            TargetedEffect(.nextStrikeDouble),
            TargetedEffect(.evadeNextHit),
        ]
    )

    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(6, keyword: .holy)]),
            AbilityOutcomeBranch(effects: [.instantHeal(.health, 6)]),
        ]
    )

    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.shield(.block, 4)),
            TargetedEffect(.thorns(4)),
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
