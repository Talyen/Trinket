import Foundation
import TrinketCore

public enum AbilityCatalogUltimate {
    public static let blizzard = Ability(
        id: "blizzard", name: "Blizzard", tier: .ultimate,
        damageComponents: [
            DamageComponent(5, keyword: .freeze, bonusAmount: 3, condition: .enemyFrozen)
        ],
        manaCost: 4
    )
    public static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        damageComponents: [
            DamageComponent(6, keyword: .burn, bonusAmount: 3, condition: .enemyBurning)
        ],
        targetedEffects: [TargetedEffect(.burn(6))],
        manaCost: 4
    )
    public static let concussiveShot = Ability(
        id: "concussive-shot", name: "Concussive Shot", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .stun)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 2), condition: .enemyStunned)],
        criticalChanceBonus: 0.10
    )
    public static let crystalBulwark = Ability(
        id: "crystal-bulwark", name: "Crystal Bulwark", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.mitigation(.armor, 0.30, 6))
        ]
    )
    public static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purge(nil))],
        manaCost: 4,
        guaranteedCriticalIfEnemyBuffed: true
    )
    public static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate,
        description: "Gain Block and deal 3 Freeze damage.",
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.instantHeal(.health, 2), condition: .enemyFrozen)
        ],
        manaCost: 3
    )
    public static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.gold, 4)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    public static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.bleed(6)),
            TargetedEffect(.standardLeechBuff)
        ],
        criticalChanceBonus: 0.15
    )
    public static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    public static let manaBulwark = Ability(
        id: "mana-bulwark", name: "Mana Bulwark", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.mana, 2)),
            TargetedEffect(.burn(2))
        ],
        manaCost: 3
    )
    public static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(6))],
        manaCost: 5,
        criticalChanceBonus: 0.10
    )
    public static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        description: "Gain Block and deal 3 Burn damage.",
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.burn(3))
        ]
    )
    public static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        damageComponents: [
            DamageComponent(5, keyword: .physical, bonusAmount: 2, condition: .allyBelowHalfHealth)
        ],
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )
    public static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 4))
        ],
        manaCost: 3
    )
    public static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(6)),
            TargetedEffect(.instantHeal(.health, 3))
        ],
        manaCost: 3
    )
    public static let serratedArrowhead = Ability(
        id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.bleed(6)),
            TargetedEffect(.poison(3))
        ]
    )
    public static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain Armor and Thorns.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.thorns(.bleed, 2, 6)),
            TargetedEffect(.bleed(1))
        ]
    )

    public static let all: [Ability] = [
        blizzard,
        combustion,
        concussiveShot,
        crystalBulwark,
        exorcism,
        glacialWard,
        goldenPlate,
        hemorrhage,
        judgment,
        manaBulwark,
        meteor,
        moltenBulwark,
        packTactics,
        panaceaPotion,
        phoenixFeather,
        serratedArrowhead,
        thornMail
    ] + AbilityCatalogUltimateGenerated.all
}
