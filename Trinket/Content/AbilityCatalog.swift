import Foundation

enum AbilityCatalog {
    static let all: [Ability] =
        AbilityCatalogBasic.all
            + AbilityCatalogSkill.all
            + AbilityCatalogUltimate.all

    static func ability(id: String) -> Ability? {
        all.first { $0.id == id }
    }
}

extension Ability {
    static let acidPotion = AbilityCatalogSkill.acidPotion
    static let antivenomPotion = AbilityCatalogSkill.antivenomPotion
    static let anvil = AbilityCatalogBasic.anvil
    static let apple = AbilityCatalogBasic.apple
    static let bash = AbilityCatalogBasic.bash
    static let blackjack = AbilityCatalogBasic.blackjack
    static let blessedAegis = AbilityCatalogUltimate.blessedAegis
    static let block = AbilityCatalogBasic.block
    static let bloodOffering = AbilityCatalogSkill.bloodOffering
    static let bloodthorn = AbilityCatalogUltimate.bloodthorn
    static let bountyShot = AbilityCatalogBasic.bountyShot
    static let bread = AbilityCatalogBasic.bread
    static let briarShield = AbilityCatalogSkill.briarShield
    static let burningBlade = AbilityCatalogSkill.burningBlade
    static let cauterize = AbilityCatalogSkill.cauterize
    static let cinderbloom = AbilityCatalogSkill.cinderbloom
    static let cleanse = AbilityCatalogSkill.cleanse
    static let coldSnap = AbilityCatalogSkill.coldSnap
    static let combustion = AbilityCatalogUltimate.combustion
    static let concussiveShot = AbilityCatalogUltimate.concussiveShot
    static let crystalBulwark = AbilityCatalogUltimate.crystalBulwark
    static let darkPact = AbilityCatalogSkill.darkPact
    static let exorcism = AbilityCatalogUltimate.exorcism
    static let fangs = AbilityCatalogBasic.fangs
    static let faustianBargain = AbilityCatalogUltimate.faustianBargain
    static let fireArrow = AbilityCatalogBasic.fireArrow
    static let fireball = AbilityCatalogSkill.fireball
    static let frostbolt = AbilityCatalogSkill.frostbolt
    static let gamblersShot = AbilityCatalogBasic.gamblersShot
    static let glacialWard = AbilityCatalogUltimate.glacialWard
    static let gold = AbilityCatalogBasic.gold
    static let goldenPlate = AbilityCatalogUltimate.goldenPlate
    static let graspingVines = AbilityCatalogSkill.graspingVines
    static let haste = AbilityCatalogSkill.haste
    static let heal = AbilityCatalogSkill.heal
    static let healthPotion = AbilityCatalogSkill.healthPotion
    static let hemorrhage = AbilityCatalogUltimate.hemorrhage
    static let holyRadiance = AbilityCatalogUltimate.holyRadiance
    static let iceShot = AbilityCatalogBasic.iceShot
    static let judgment = AbilityCatalogUltimate.judgment
    static let kindling = AbilityCatalogBasic.kindling
    static let lightningArrow = AbilityCatalogSkill.lightningArrow
    static let lightningBolt = AbilityCatalogSkill.lightningBolt
    static let luckPotion = AbilityCatalogUltimate.luckPotion
    static let manaBerries = AbilityCatalogBasic.manaBerries
    static let manaCrystals = AbilityCatalogBasic.manaCrystals
    static let manaPotion = AbilityCatalogSkill.manaPotion
    static let manaShield = AbilityCatalogSkill.manaShield
    static let meteor = AbilityCatalogUltimate.meteor
    static let moltenBulwark = AbilityCatalogUltimate.moltenBulwark
    static let packTactics = AbilityCatalogUltimate.packTactics
    static let panaceaPotion = AbilityCatalogUltimate.panaceaPotion
    static let phoenixFeather = AbilityCatalogUltimate.phoenixFeather
    static let plateMail = AbilityCatalogUltimate.plateMail
    static let poisonDagger = AbilityCatalogSkill.poisonDagger
    static let prayer = AbilityCatalogSkill.prayer
    static let rayOfFrost = AbilityCatalogBasic.rayOfFrost
    static let roulette = AbilityCatalogSkill.roulette
    static let sanctifiedPlate = AbilityCatalogUltimate.sanctifiedPlate
    static let sapArrow = AbilityCatalogSkill.sapArrow
    static let serratedArrowhead = AbilityCatalogUltimate.serratedArrowhead
    static let serratedEdge = AbilityCatalogSkill.serratedEdge
    static let shieldBash = AbilityCatalogBasic.shieldBash
    static let slash = AbilityCatalogBasic.slash
    static let smellingSalts = AbilityCatalogBasic.smellingSalts
    static let smite = AbilityCatalogSkill.smite
    static let spikedShield = AbilityCatalogSkill.spikedShield
    static let stab = AbilityCatalogBasic.stab
    static let steal = AbilityCatalogSkill.steal
    static let stoneskinPotion = AbilityCatalogSkill.stoneskinPotion
    static let sunburst = AbilityCatalogUltimate.sunburst
    static let sunderArmor = AbilityCatalogSkill.sunderArmor
    static let thornMail = AbilityCatalogUltimate.thornMail
    static let tithe = AbilityCatalogSkill.tithe
    static let venomArrow = AbilityCatalogSkill.venomArrow
    static let venomFangs = AbilityCatalogSkill.venomFangs
}
