import Foundation

enum AbilityCatalog {
    static let all: [Ability] = AbilityCatalogEntries.all

    static func ability(id: String) -> Ability? {
        all.first { $0.id == id }
    }
}

extension Ability {
    static let acidPotion = AbilityCatalogEntriesA.acidPotion
    static let antivenomPotion = AbilityCatalogEntriesA.antivenomPotion
    static let anvil = AbilityCatalogEntriesA.anvil
    static let apple = AbilityCatalogEntriesA.apple
    static let bash = AbilityCatalogEntriesA.bash
    static let blackjack = AbilityCatalogEntriesA.blackjack
    static let blessedAegis = AbilityCatalogEntriesA.blessedAegis
    static let block = AbilityCatalogEntriesA.block
    static let bloodOffering = AbilityCatalogEntriesA.bloodOffering
    static let bloodthorn = AbilityCatalogEntriesA.bloodthorn
    static let bountyShot = AbilityCatalogEntriesA.bountyShot
    static let bread = AbilityCatalogEntriesA.bread
    static let briarShield = AbilityCatalogEntriesA.briarShield
    static let burningBlade = AbilityCatalogEntriesA.burningBlade
    static let cauterize = AbilityCatalogEntriesA.cauterize
    static let cinderbloom = AbilityCatalogEntriesA.cinderbloom
    static let cleanse = AbilityCatalogEntriesA.cleanse
    static let coldSnap = AbilityCatalogEntriesA.coldSnap
    static let combustion = AbilityCatalogEntriesA.combustion
    static let concussiveShot = AbilityCatalogEntriesA.concussiveShot
    static let crystalBulwark = AbilityCatalogEntriesA.crystalBulwark
    static let darkPact = AbilityCatalogEntriesA.darkPact
    static let exorcism = AbilityCatalogEntriesA.exorcism
    static let fangs = AbilityCatalogEntriesA.fangs
    static let faustianBargain = AbilityCatalogEntriesA.faustianBargain
    static let fireArrow = AbilityCatalogEntriesA.fireArrow
    static let fireball = AbilityCatalogEntriesA.fireball
    static let frostbolt = AbilityCatalogEntriesA.frostbolt
    static let gamblersShot = AbilityCatalogEntriesA.gamblersShot
    static let glacialWard = AbilityCatalogEntriesA.glacialWard
    static let gold = AbilityCatalogEntriesA.gold
    static let goldenPlate = AbilityCatalogEntriesA.goldenPlate
    static let graspingVines = AbilityCatalogEntriesA.graspingVines
    static let haste = AbilityCatalogEntriesA.haste
    static let heal = AbilityCatalogEntriesA.heal
    static let healthPotion = AbilityCatalogEntriesA.healthPotion
    static let hemorrhage = AbilityCatalogEntriesA.hemorrhage
    static let holyRadiance = AbilityCatalogEntriesA.holyRadiance
    static let iceShot = AbilityCatalogEntriesB.iceShot
    static let judgment = AbilityCatalogEntriesB.judgment
    static let kindling = AbilityCatalogEntriesB.kindling
    static let lightningArrow = AbilityCatalogEntriesB.lightningArrow
    static let lightningBolt = AbilityCatalogEntriesB.lightningBolt
    static let luckPotion = AbilityCatalogEntriesB.luckPotion
    static let manaBerries = AbilityCatalogEntriesB.manaBerries
    static let manaCrystals = AbilityCatalogEntriesB.manaCrystals
    static let manaPotion = AbilityCatalogEntriesB.manaPotion
    static let manaShield = AbilityCatalogEntriesB.manaShield
    static let meteor = AbilityCatalogEntriesB.meteor
    static let moltenBulwark = AbilityCatalogEntriesB.moltenBulwark
    static let packTactics = AbilityCatalogEntriesB.packTactics
    static let panaceaPotion = AbilityCatalogEntriesB.panaceaPotion
    static let phoenixFeather = AbilityCatalogEntriesB.phoenixFeather
    static let plateMail = AbilityCatalogEntriesB.plateMail
    static let poisonDagger = AbilityCatalogEntriesB.poisonDagger
    static let prayer = AbilityCatalogEntriesB.prayer
    static let rayOfFrost = AbilityCatalogEntriesB.rayOfFrost
    static let roulette = AbilityCatalogEntriesB.roulette
    static let sanctifiedPlate = AbilityCatalogEntriesB.sanctifiedPlate
    static let sapArrow = AbilityCatalogEntriesB.sapArrow
    static let serratedArrowhead = AbilityCatalogEntriesB.serratedArrowhead
    static let serratedEdge = AbilityCatalogEntriesB.serratedEdge
    static let shieldBash = AbilityCatalogEntriesB.shieldBash
    static let slash = AbilityCatalogEntriesB.slash
    static let smellingSalts = AbilityCatalogEntriesB.smellingSalts
    static let smite = AbilityCatalogEntriesB.smite
    static let spikedShield = AbilityCatalogEntriesB.spikedShield
    static let stab = AbilityCatalogEntriesB.stab
    static let steal = AbilityCatalogEntriesB.steal
    static let stoneskinPotion = AbilityCatalogEntriesB.stoneskinPotion
    static let sunburst = AbilityCatalogEntriesB.sunburst
    static let sunderArmor = AbilityCatalogEntriesB.sunderArmor
    static let thornMail = AbilityCatalogEntriesB.thornMail
    static let tithe = AbilityCatalogEntriesB.tithe
    static let venomArrow = AbilityCatalogEntriesB.venomArrow
    static let venomFangs = AbilityCatalogEntriesB.venomFangs
}
