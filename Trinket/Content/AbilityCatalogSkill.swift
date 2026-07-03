import Foundation

enum AbilityCatalogSkill {
    static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .poison)],
        targetedEffects: [TargetedEffect(.poison(3))]
    )

    static let antivenomPotion = Ability(
        id: "antivenom-potion", name: "Antivenom Potion", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(.poison)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )

    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )

    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill,
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.25, 6))
        ]
    )

    static let burningBlade = Ability(
        id: "burning-blade", name: "Burning Blade", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(3))]
    )

    static let cauterize = Ability(
        id: "cauterize", name: "Cauterize", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )

    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(3))]
    )

    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill,
        targetedEffects: [
            TargetedEffect(.cleanse(nil)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )

    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: []
    )

    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff)
        ]
    )

    static let fireball = Ability(
        id: "fireball", name: "Fireball", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(3))]
    )

    static let frostbolt = Ability(
        id: "frostbolt", name: "Frostbolt", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: []
    )

    static let graspingVines = Ability(
        id: "grasping-vines", name: "Grasping Vines", tier: .skill,
        description: "Deal 3 Nature damage.\nRestore 1 Health.",
        damageComponents: [DamageComponent(3, keyword: .nature)],
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )

    static let haste = Ability(
        id: "haste", name: "Haste", tier: .skill,
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.25, 6))]
    )

    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )

    static let healthPotion = Ability(
        id: "health-potion", name: "Health Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
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

    static let roulette = Ability(
        id: "roulette", name: "Roulette", tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )

    static let sapArrow = Ability(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .stun)],
        targetedEffects: []
    )

    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill,
        damageComponents: [DamageComponent(3, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(3))]
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

    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )

    static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill,
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.30, 6))]
    )

    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        damageComponents: [DamageComponent(3)],
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
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

    static let all: [Ability] = [
        acidPotion,
        antivenomPotion,
        bloodOffering,
        briarShield,
        burningBlade,
        cauterize,
        cinderbloom,
        cleanse,
        coldSnap,
        darkPact,
        fireball,
        frostbolt,
        graspingVines,
        haste,
        heal,
        healthPotion,
        lightningArrow,
        lightningBolt,
        manaPotion,
        manaShield,
        poisonDagger,
        prayer,
        roulette,
        sapArrow,
        serratedEdge,
        smite,
        spikedShield,
        steal,
        stoneskinPotion,
        sunderArmor,
        tithe,
        venomArrow,
        venomFangs
    ]
}
