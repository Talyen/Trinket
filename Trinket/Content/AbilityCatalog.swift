import Foundation

enum AbilityCatalog {
    static let acidPotion = Ability(
        id: "acid-potion", name: "Acid Potion", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let antivenomPotion = Ability(
        id: "antivenom-potion", name: "Antivenom Potion", tier: .skill, directDamage: 0,
        description: "Cleanse Poisoned and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(.poison, 0)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let anvil = Ability(
        id: "anvil", name: "Anvil", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.",
        targetedEffects: []
    )
    static let apple = Ability(
        id: "apple", name: "Apple", tier: .basic, directDamage: 0,
        description: "Restore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let bash = Ability(
        id: "bash", name: "Bash", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.",
        targetedEffects: []
    )
    static let blackjack = Ability(
        id: "blackjack", name: "Blackjack", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.\nGain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let blessedAegis = Ability(
        id: "blessed-aegis", name: "Blessed Aegis", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 4, 6))]
    )
    static let block = Ability(
        id: "block", name: "Block", tier: .basic, directDamage: 0,
        description: "Gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 2, 6))]
    )
    static let bloodOffering = Ability(
        id: "blood-offering", name: "Blood Offering", tier: .skill, directDamage: 0,
        description: "Lose 2 Health and gain Leech.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.physical, 2), target: .actor),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let bloodthorn = Ability(
        id: "bloodthorn", name: "Bloodthorn", tier: .ultimate, directDamage: 0,
        description: "Deal 2 Nature, 2 Bleed, and 2 Poison damage and gain Leech.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.nature, 2)),
            TargetedEffect(.dealDamage(.bleed, 2)),
            TargetedEffect(.bleed(2)),
            TargetedEffect(.dealDamage(.poison, 2)),
            TargetedEffect(.poison(2)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let bountyShot = Ability(
        id: "bounty-shot", name: "Bounty Shot", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage and gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let bread = Ability(
        id: "bread", name: "Bread", tier: .basic, directDamage: 0,
        description: "Restore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let briarShield = Ability(
        id: "briar-shield", name: "Briar Shield", tier: .skill, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.25, 6))
        ]
    )
    static let burningBlade = Ability(
        id: "burning-blade", name: "Burning Blade", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let cauterize = Ability(
        id: "cauterize", name: "Cauterize", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage, applies Burning, and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.burn(3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let cinderbloom = Ability(
        id: "cinderbloom", name: "Cinderbloom", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let cleanse = Ability(
        id: "cleanse", name: "Cleanse", tier: .skill, directDamage: 0,
        description: "Cleanse all debuffs and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(nil, 0)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let coldSnap = Ability(
        id: "cold-snap", name: "Cold Snap", tier: .skill, directDamage: 3, damageKeyword: .freeze,
        description: "Deal 3 Freeze damage.",
        targetedEffects: []
    )
    static let combustion = Ability(
        id: "combustion", name: "Combustion", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(6))]
    )
    static let concussiveShot = Ability(
        id: "concussive-shot", name: "Concussive Shot", tier: .ultimate, directDamage: 6, damageKeyword: .stun,
        description: "Deal 6 Stun damage.",
        targetedEffects: []
    )
    static let crystalBulwark = Ability(
        id: "crystal-bulwark", name: "Crystal Bulwark", tier: .ultimate, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 5, 6)),
            TargetedEffect(.mitigation(.armor, 0.35, 6))
        ]
    )
    static let darkPact = Ability(
        id: "dark-pact", name: "Dark Pact", tier: .skill, directDamage: 0,
        description: "Restore 3 Health and gain Leech.",
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let exorcism = Ability(
        id: "exorcism", name: "Exorcism", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and cleanse all debuffs.",
        targetedEffects: [TargetedEffect(.cleanse(nil, 0), target: .abilityTarget)]
    )
    static let fangs = Ability(
        id: "fangs", name: "Fangs", tier: .basic, directDamage: 1, damageKeyword: .bleed,
        description: "Deal 1 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(1))]
    )
    static let faustianBargain = Ability(
        id: "faustian-bargain", name: "Faustian Bargain", tier: .ultimate, directDamage: 6,
        description: "Lose 3 Health, deal 6 Physical damage, and gain 3 Gold.",
        targetedEffects: [
            TargetedEffect(.dealDamage(.physical, 3), target: .actor),
            TargetedEffect(.resourceGain(.gold, 3))
        ]
    )
    static let fireArrow = Ability(
        id: "fire-arrow", name: "Fire Arrow", tier: .basic, directDamage: 1, damageKeyword: .burn,
        description: "Deal 1 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let fireball = Ability(
        id: "fireball", name: "Fireball", tier: .skill, directDamage: 3, damageKeyword: .burn,
        description: "Deal 3 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(3))]
    )
    static let frostbolt = Ability(
        id: "frostbolt", name: "Frostbolt", tier: .skill, directDamage: 3, damageKeyword: .freeze,
        description: "Deal 3 Freeze damage.",
        targetedEffects: []
    )
    static let gamblersShot = Ability(
        id: "gamblers-shot", name: "Gambler's Shot", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage and gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let glacialWard = Ability(
        id: "glacial-ward", name: "Glacial Ward", tier: .ultimate, directDamage: 3, damageKeyword: .freeze,
        description: "Gain Block and deal 3 Freeze damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6))
        ]
    )
    static let gold = Ability(
        id: "gold", name: "Gold", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let goldenPlate = Ability(
        id: "golden-plate", name: "Golden Plate", tier: .ultimate, directDamage: 0,
        description: "Gain Armor and gain 4 Gold.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.resourceGain(.gold, 4))
        ]
    )
    static let graspingVines = Ability(
        id: "grasping-vines", name: "Grasping Vines", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.\nRestore 1 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 1))]
    )
    static let haste = Ability(
        id: "haste", name: "Haste", tier: .skill, directDamage: 0,
        description: "Gain Armor.",
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.25, 6))]
    )
    static let heal = Ability(
        id: "heal", name: "Heal", tier: .skill, directDamage: 0,
        description: "Restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let healthPotion = Ability(
        id: "health-potion", name: "Health Potion", tier: .skill, directDamage: 0,
        description: "Restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let hemorrhage = Ability(
        id: "hemorrhage", name: "Hemorrhage", tier: .ultimate, directDamage: 6, damageKeyword: .bleed,
        description: "Deal 6 Bleed damage, applies Bleeding, and gain Leech.",
        targetedEffects: [
            TargetedEffect(.bleed(6)),
            TargetedEffect(.standardLeechBuff)
        ]
    )
    static let holyRadiance = Ability(
        id: "holy-radiance", name: "Holy Radiance", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and restore 3 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 3))]
    )
    static let iceShot = Ability(
        id: "ice-shot", name: "Ice Shot", tier: .basic, directDamage: 1, damageKeyword: .freeze,
        description: "Deal 1 Freeze damage.",
        targetedEffects: []
    )
    static let judgment = Ability(
        id: "judgment", name: "Judgment", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage.\nGain 1 Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    static let kindling = Ability(
        id: "kindling", name: "Kindling", tier: .basic, directDamage: 1, damageKeyword: .burn,
        description: "Deal 1 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(1))]
    )
    static let lightningArrow = Ability(
        id: "lightning-arrow", name: "Lightning Arrow", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.",
        targetedEffects: []
    )
    static let lightningBolt = Ability(
        id: "lightning-bolt", name: "Lightning Bolt", tier: .skill, directDamage: 3, damageKeyword: .nature,
        description: "Deal 3 Nature damage.",
        targetedEffects: []
    )
    static let luckPotion = Ability(
        id: "luck-potion", name: "Luck Potion", tier: .ultimate, directDamage: 0,
        description: "Gain 3 Gold and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 3)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let manaBerries = Ability(
        id: "mana-berries", name: "Mana Berries", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaCrystals = Ability(
        id: "mana-crystals", name: "Mana Crystals", tier: .basic, directDamage: 0,
        description: "Gain 1 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 1))]
    )
    static let manaPotion = Ability(
        id: "mana-potion", name: "Mana Potion", tier: .skill, directDamage: 0,
        description: "Gain 2 Gold and gain Block.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.shield(.block, 2, 6))
        ]
    )
    static let manaShield = Ability(
        id: "mana-shield", name: "Mana Shield", tier: .skill, directDamage: 0,
        description: "Gain Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 3, 6))]
    )
    static let meteor = Ability(
        id: "meteor", name: "Meteor", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage and applies Burning.",
        targetedEffects: [TargetedEffect(.burn(6))]
    )
    static let moltenBulwark = Ability(
        id: "molten-bulwark", name: "Molten Bulwark", tier: .ultimate, directDamage: 3, damageKeyword: .burn,
        description: "Gain Block and deal 3 Burn damage.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.burn(3))
        ]
    )
    static let packTactics = Ability(
        id: "pack-tactics", name: "Pack Tactics", tier: .ultimate, directDamage: 3,
        description: "Deal 3 Physical damage and gain Leech.",
        targetedEffects: [TargetedEffect(.standardLeechBuff)]
    )
    static let panaceaPotion = Ability(
        id: "panacea-potion", name: "Panacea Potion", tier: .ultimate, directDamage: 0,
        description: "Cleanse all debuffs and restore 4 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(nil, 0)),
            TargetedEffect(.instantHeal(.health, 4))
        ]
    )
    static let phoenixFeather = Ability(
        id: "phoenix-feather", name: "Phoenix Feather", tier: .ultimate, directDamage: 6, damageKeyword: .burn,
        description: "Deal 6 Burn damage, applies Burning, and restore 3 Health.",
        targetedEffects: [
            TargetedEffect(.burn(6)),
            TargetedEffect(.instantHeal(.health, 3))
        ]
    )
    static let plateMail = Ability(
        id: "plate-mail", name: "Plate Mail", tier: .ultimate, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 4, 6)),
            TargetedEffect(.mitigation(.armor, 0.30, 6))
        ]
    )
    static let poisonDagger = Ability(
        id: "poison-dagger", name: "Poison Dagger", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let prayer = Ability(
        id: "prayer", name: "Prayer", tier: .skill, directDamage: 0,
        description: "Restore 2 Health and cleanse a random debuff.",
        targetedEffects: [
            TargetedEffect(.instantHeal(.health, 2)),
            TargetedEffect(.cleanseRandom)
        ]
    )
    static let rayOfFrost = Ability(
        id: "ray-of-frost", name: "Ray of Frost", tier: .basic, directDamage: 1, damageKeyword: .freeze,
        description: "Deal 1 Freeze damage.",
        targetedEffects: []
    )
    static let roulette = Ability(
        id: "roulette", name: "Roulette", tier: .skill, directDamage: 3,
        description: "Deal 3 Physical damage and gain 3 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let sanctifiedPlate = Ability(
        id: "sanctified-plate", name: "Sanctified Plate", tier: .ultimate, directDamage: 0, damageKeyword: .holy,
        description: "Gain Armor and restore 2 Health.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.30, 6)),
            TargetedEffect(.instantHeal(.health, 2))
        ]
    )
    static let sapArrow = Ability(
        id: "sap-arrow", name: "Sap Arrow", tier: .skill, directDamage: 3, damageKeyword: .stun,
        description: "Deal 3 Stun damage.",
        targetedEffects: []
    )
    static let serratedArrowhead = Ability(
        id: "serrated-arrowhead", name: "Serrated Arrowhead", tier: .ultimate, directDamage: 6, damageKeyword: .bleed,
        description: "Deal 6 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(6))]
    )
    static let serratedEdge = Ability(
        id: "serrated-edge", name: "Serrated Edge", tier: .skill, directDamage: 3, damageKeyword: .bleed,
        description: "Deal 3 Bleed damage and applies Bleeding.",
        targetedEffects: [TargetedEffect(.bleed(3))]
    )
    static let shieldBash = Ability(
        id: "shield-bash", name: "Shield Bash", tier: .basic, directDamage: 1, damageKeyword: .stun,
        description: "Deal 1 Stun damage.\nGain 1 Block.",
        targetedEffects: [TargetedEffect(.shield(.block, 1, 6))]
    )
    static let slash = Ability(
        id: "slash", name: "Slash", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage."
    )
    static let smellingSalts = Ability(
        id: "smelling-salts", name: "Smelling Salts", tier: .basic, directDamage: 0,
        description: "Cleanse Stunned and restore 1 Health.",
        targetedEffects: [
            TargetedEffect(.cleanse(.stun, 0)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )
    static let smite = Ability(
        id: "smite", name: "Smite", tier: .skill, directDamage: 3, damageKeyword: .holy,
        description: "Deal 3 Holy damage."
    )
    static let spikedShield = Ability(
        id: "spiked-shield", name: "Spiked Shield", tier: .skill, directDamage: 0,
        description: "Gain Block and gain Armor.",
        targetedEffects: [
            TargetedEffect(.shield(.block, 3, 6)),
            TargetedEffect(.mitigation(.armor, 0.20, 6))
        ]
    )
    static let stab = Ability(
        id: "stab", name: "Stab", tier: .basic, directDamage: 1,
        description: "Deal 1 Physical damage."
    )
    static let steal = Ability(
        id: "steal", name: "Steal", tier: .skill, directDamage: 3,
        description: "Deal 3 Physical damage and gain 3 Gold.",
        targetedEffects: [TargetedEffect(.resourceGain(.gold, 3))]
    )
    static let stoneskinPotion = Ability(
        id: "stoneskin-potion", name: "Stoneskin Potion", tier: .skill, directDamage: 0,
        description: "Gain Armor.",
        targetedEffects: [TargetedEffect(.mitigation(.armor, 0.30, 6))]
    )
    static let sunburst = Ability(
        id: "sunburst", name: "Sunburst", tier: .ultimate, directDamage: 6, damageKeyword: .holy,
        description: "Deal 6 Holy damage and restore 2 Health.",
        targetedEffects: [TargetedEffect(.instantHeal(.health, 2))]
    )
    static let sunderArmor = Ability(
        id: "sunder-armor",
        name: "Sunder Armor",
        tier: .skill,
        directDamage: 3,
        description: "Deal 3 Physical damage and reduce enemy Armor by half.",
        targetedEffects: [TargetedEffect(.halveMitigation(.armor), target: .enemy)]
    )
    static let thornMail = Ability(
        id: "thorn-mail", name: "Thorn Mail", tier: .ultimate, directDamage: 2, damageKeyword: .bleed,
        description: "Gain Armor and deal 2 Bleed damage.",
        targetedEffects: [
            TargetedEffect(.mitigation(.armor, 0.25, 6)),
            TargetedEffect(.bleed(2))
        ]
    )
    static let tithe = Ability(
        id: "tithe", name: "Tithe", tier: .skill, directDamage: 0,
        description: "Gain 2 Gold and restore 1 Health.",
        targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 2)),
            TargetedEffect(.instantHeal(.health, 1))
        ]
    )
    static let venomArrow = Ability(
        id: "venom-arrow", name: "Venom Arrow", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )
    static let venomFangs = Ability(
        id: "venom-fangs", name: "Venom Fangs", tier: .skill, directDamage: 3, damageKeyword: .poison,
        description: "Deal 3 Poison damage and applies Poisoned.",
        targetedEffects: [TargetedEffect(.poison(3))]
    )

    static let all: [Ability] = [
            acidPotion,
            antivenomPotion,
            anvil,
            apple,
            bash,
            blackjack,
            blessedAegis,
            block,
            bloodOffering,
            bloodthorn,
            bountyShot,
            bread,
            briarShield,
            burningBlade,
            cauterize,
            cinderbloom,
            cleanse,
            coldSnap,
            combustion,
            concussiveShot,
            crystalBulwark,
            darkPact,
            exorcism,
            fangs,
            faustianBargain,
            fireArrow,
            fireball,
            frostbolt,
            gamblersShot,
            glacialWard,
            gold,
            goldenPlate,
            graspingVines,
            haste,
            heal,
            healthPotion,
            hemorrhage,
            holyRadiance,
            iceShot,
            judgment,
            kindling,
            lightningArrow,
            lightningBolt,
            luckPotion,
            manaBerries,
            manaCrystals,
            manaPotion,
            manaShield,
            meteor,
            moltenBulwark,
            packTactics,
            panaceaPotion,
            phoenixFeather,
            plateMail,
            poisonDagger,
            prayer,
            rayOfFrost,
            roulette,
            sanctifiedPlate,
            sapArrow,
            serratedArrowhead,
            serratedEdge,
            shieldBash,
            slash,
            smellingSalts,
            smite,
            spikedShield,
            stab,
            steal,
            stoneskinPotion,
            sunburst,
            sunderArmor,
            thornMail,
            tithe,
            venomArrow,
            venomFangs
    ]

    static func ability(id: String) -> Ability? {
        all.first { $0.id == id }
    }
}

extension Ability {
    static let acidPotion = AbilityCatalog.acidPotion
    static let antivenomPotion = AbilityCatalog.antivenomPotion
    static let anvil = AbilityCatalog.anvil
    static let apple = AbilityCatalog.apple
    static let bash = AbilityCatalog.bash
    static let blackjack = AbilityCatalog.blackjack
    static let blessedAegis = AbilityCatalog.blessedAegis
    static let block = AbilityCatalog.block
    static let bloodOffering = AbilityCatalog.bloodOffering
    static let bloodthorn = AbilityCatalog.bloodthorn
    static let bountyShot = AbilityCatalog.bountyShot
    static let bread = AbilityCatalog.bread
    static let briarShield = AbilityCatalog.briarShield
    static let burningBlade = AbilityCatalog.burningBlade
    static let cauterize = AbilityCatalog.cauterize
    static let cinderbloom = AbilityCatalog.cinderbloom
    static let cleanse = AbilityCatalog.cleanse
    static let coldSnap = AbilityCatalog.coldSnap
    static let combustion = AbilityCatalog.combustion
    static let concussiveShot = AbilityCatalog.concussiveShot
    static let crystalBulwark = AbilityCatalog.crystalBulwark
    static let darkPact = AbilityCatalog.darkPact
    static let exorcism = AbilityCatalog.exorcism
    static let fangs = AbilityCatalog.fangs
    static let faustianBargain = AbilityCatalog.faustianBargain
    static let fireArrow = AbilityCatalog.fireArrow
    static let fireball = AbilityCatalog.fireball
    static let frostbolt = AbilityCatalog.frostbolt
    static let gamblersShot = AbilityCatalog.gamblersShot
    static let glacialWard = AbilityCatalog.glacialWard
    static let gold = AbilityCatalog.gold
    static let goldenPlate = AbilityCatalog.goldenPlate
    static let graspingVines = AbilityCatalog.graspingVines
    static let haste = AbilityCatalog.haste
    static let heal = AbilityCatalog.heal
    static let healthPotion = AbilityCatalog.healthPotion
    static let hemorrhage = AbilityCatalog.hemorrhage
    static let holyRadiance = AbilityCatalog.holyRadiance
    static let iceShot = AbilityCatalog.iceShot
    static let judgment = AbilityCatalog.judgment
    static let kindling = AbilityCatalog.kindling
    static let lightningArrow = AbilityCatalog.lightningArrow
    static let lightningBolt = AbilityCatalog.lightningBolt
    static let luckPotion = AbilityCatalog.luckPotion
    static let manaBerries = AbilityCatalog.manaBerries
    static let manaCrystals = AbilityCatalog.manaCrystals
    static let manaPotion = AbilityCatalog.manaPotion
    static let manaShield = AbilityCatalog.manaShield
    static let meteor = AbilityCatalog.meteor
    static let moltenBulwark = AbilityCatalog.moltenBulwark
    static let packTactics = AbilityCatalog.packTactics
    static let panaceaPotion = AbilityCatalog.panaceaPotion
    static let phoenixFeather = AbilityCatalog.phoenixFeather
    static let plateMail = AbilityCatalog.plateMail
    static let poisonDagger = AbilityCatalog.poisonDagger
    static let prayer = AbilityCatalog.prayer
    static let rayOfFrost = AbilityCatalog.rayOfFrost
    static let roulette = AbilityCatalog.roulette
    static let sanctifiedPlate = AbilityCatalog.sanctifiedPlate
    static let sapArrow = AbilityCatalog.sapArrow
    static let serratedArrowhead = AbilityCatalog.serratedArrowhead
    static let serratedEdge = AbilityCatalog.serratedEdge
    static let shieldBash = AbilityCatalog.shieldBash
    static let slash = AbilityCatalog.slash
    static let smellingSalts = AbilityCatalog.smellingSalts
    static let smite = AbilityCatalog.smite
    static let spikedShield = AbilityCatalog.spikedShield
    static let stab = AbilityCatalog.stab
    static let steal = AbilityCatalog.steal
    static let stoneskinPotion = AbilityCatalog.stoneskinPotion
    static let sunburst = AbilityCatalog.sunburst
    static let sunderArmor = AbilityCatalog.sunderArmor
    static let thornMail = AbilityCatalog.thornMail
    static let tithe = AbilityCatalog.tithe
    static let venomArrow = AbilityCatalog.venomArrow
    static let venomFangs = AbilityCatalog.venomFangs
}
