import Foundation

enum AbilityCatalogUltimate {
    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 4, 6))]
    )

    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate,
        damageComponents: [
            DamageComponent(2, keyword: .nature),
            DamageComponent(2, keyword: .bleed),
            DamageComponent(2, keyword: .poison)
        ],
        targetedEffects: [
            TargetedEffect(.bleed(2)),
            TargetedEffect(.poison(2)),
            TargetedEffect(.standardLeechBuff)
        ]
    )

    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(6))]
    )

    static let concussiveShot = Ability(
        id: "concussive-shot", name: "Concussive Shot", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .stun)],
        targetedEffects: []
    )

    static let crystalBulwark = Ability(
        id: "crystal-bulwark", name: "Crystal Bulwark", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.shield(.block, 5, 6)),
            TargetedEffect(.mitigation(.armor, 0.35, 6))
        ]
    )

    static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purge(nil))]
    )

    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        damageComponents: [
            DamageComponent(6, keyword: .physical),
            DamageComponent(3, keyword: .physical, target: .actor)
        ],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )

    static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate,
        description: "Gain Block and deal 3 Freeze damage.",
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6))
        ]
    )

    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.gold, 4))
        ]
    )

    static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.bleed(6)),
            TargetedEffect(.standardLeechBuff)
        ]
    )

    static let holyRadiance = Ability(
        id: "holy-radiance", name: "Holy Radiance", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )

    static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )

    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )

    static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(6))]
    )

    static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate,
        description: "Gain Block and deal 3 Burn damage.",
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.burn(3))
        ]
    )

    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )

    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 4))
        ]
    )

    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(6)),
            TargetedEffect(.instantHeal(.health, 3))
        ]
    )

    static let plateMail = Ability(
        id: "plate-mail", name: "Plate Mail", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.mitigation(.armor, 0.30, 6))
        ]
    )

    static let sanctifiedPlate = Ability(
        id: "sanctified-plate", name: "Sanctified Plate", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )

    static let serratedArrowhead = Ability(
        id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(6))]
    )

    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 2))]
    )

    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate,
        description: "Gain Armor and deal 2 Bleed damage.",
        damageComponents: [DamageComponent(2, keyword: .bleed)],
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.bleed(2))
        ]
    )

    static let all: [Ability] = [
        blessedAegis,
        bloodthorn,
        combustion,
        concussiveShot,
        crystalBulwark,
        exorcism,
        faustianBargain,
        glacialWard,
        goldenPlate,
        hemorrhage,
        holyRadiance,
        judgment,
        luckPotion,
        meteor,
        moltenBulwark,
        packTactics,
        panaceaPotion,
        phoenixFeather,
        plateMail,
        sanctifiedPlate,
        serratedArrowhead,
        sunburst,
        thornMail
    ]
}
