import Foundation

enum AbilityCatalogEntriesB {
    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: []
    )
    static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let lightningArrow = Ability(
        id: "lightning-arrow", name: "Lightning Arrow", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .nature)],
        targetedEffects: []
    )
    static let lightningBolt = Ability(
        id: "lightning-bolt", name: "Lightning Bolt", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .nature)],
        targetedEffects: []
    )
    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaCrystals = Ability(
        id: "mana-crystals", name: "Mana Crystals", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.shield(.block, 2, 6))
        ]
    )
    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill,
        targetedEffects: [TargetedEffect(.shield(.block, 3, 6))]
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
    static let poisonDagger = Ability(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .freeze)],
        targetedEffects: []
    )
    static let roulette = Ability(
        id: "roulette", name: "Roulette", tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let sanctifiedPlate = Ability(
        id: "sanctified-plate", name: "Sanctified Plate", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let sapArrow = Ability(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .stun)],
        targetedEffects: []
    )
    static let serratedArrowhead = Ability(
        id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(6))]
    )
    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(3))]
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
    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .holy)]
    )
    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.20, 6))
        ]
    )
    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic,
        damageComponents: [DamageComponent(1)]
    )
    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.30, 6))]
    )
    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 2))]
    )
    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
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
    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill,
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )
    static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(3))]
    )
}
