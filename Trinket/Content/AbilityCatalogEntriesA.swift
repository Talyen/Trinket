import Foundation

enum AbilityCatalogEntriesA {
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
    static let anvil = Ability(
        id: "anvil", name: "Anvil", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: []
    )
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: []
    )
    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic,
        description: "Deal 1 Stun damage.\nGain 1 Gold.",
        damageComponents: [DamageComponent(1, keyword: .stun)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.shield(.block, 4, 6))]
    )
    static let block = Ability(
        id: "block", name: "Block", tier: .basic,
        targetedEffects: [TargetedEffect(.shield(.block, 2, 6))]
    )
    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill,
        damageComponents: [DamageComponent(2, keyword: .physical, target: .actor)],
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
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
    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .basic,
        damageComponents: [DamageComponent(1)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let bread = Ability(
        id: "bread", name: "Bread", tier: .basic,
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
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
    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill,
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate,
        damageComponents: [DamageComponent(6, keyword: .holy)],
        targetedEffects: [TargetedEffect(.purge(nil))]
    )
    static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .bleed)],
        targetedEffects: [TargetedEffect(.bleed(1))]
    )
    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate,
        damageComponents: [
            DamageComponent(6, keyword: .physical),
            DamageComponent(3, keyword: .physical, target: .actor)
        ],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic,
        damageComponents: [DamageComponent(1, keyword: .burn)],
        targetedEffects: [TargetedEffect(.burn(1))]
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
    static let gamblersShot = Ability(
        id: "gamblers-shot", name: "Gambler's Shot", tier: .basic,
        damageComponents: [DamageComponent(1)],
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate,
        description: "Gain Block and deal 3 Freeze damage.",
        damageComponents: [DamageComponent(3, keyword: .freeze)],
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6))
        ]
    )
    static let gold = Ability(
        id: "gold", name: "Gold", tier: .basic,
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate,
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.gold, 4))
        ]
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
}
