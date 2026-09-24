import Testing
import TrinketContent
import TrinketCore

struct AlchemyAffixCatalogTests {
    @Test func `compatible affixes keep their authored rarity baselines and can roll on an item`() throws {
        let spitebloom = try #require(GameContent.itemAffixDefinition(matching: "spitebloom"))
        let bloodroot = try #require(GameContent.itemAffixDefinition(matching: "bloodroot"))
        let heartshock = try #require(GameContent.itemAffixDefinition(matching: "heartshock"))
        let venomtrail = try #require(GameContent.itemAffixDefinition(matching: "venomtrail"))
        let hallowguard = try #require(GameContent.itemAffixDefinition(matching: "hallowguard"))
        let hallowbreak = try #require(GameContent.itemAffixDefinition(matching: "hallowbreak"))

        #expect(spitebloom.basic.triggers.poisonOnThornsDamage == 1)
        #expect(spitebloom.astral.triggers.poisonOnThornsDamage == 3)
        #expect(bloodroot.basic.triggers.leechThornsWithoutThorns == 1)
        #expect(bloodroot.astral.triggers.leechThornsWithoutThorns == 3)
        #expect(heartshock.basic.triggers.leechStunBelowHalfHealth == 1)
        #expect(heartshock.astral.triggers.leechStunBelowHalfHealth == 3)
        #expect(venomtrail.basic.triggers.poisonDamageVsBleedingFlat == 1)
        #expect(venomtrail.astral.triggers.poisonDamageVsBleedingFlat == 3)
        #expect(hallowguard.basic.triggers.holyAttackBlockIfNone == 3)
        #expect(hallowguard.astral.triggers.holyAttackBlockIfNone == 5)
        #expect(hallowbreak.basic.triggers.holyDamageVsStunnedPercent == 0.25)
        #expect(hallowbreak.astral.triggers.holyDamageVsStunnedPercent == 0.35)

        for affix in [spitebloom, bloodroot, heartshock, venomtrail, hallowguard, hallowbreak] {
            #expect(GameContent.itemBaseTypes.contains { base in
                base.slot == affix.slot && !base.keywordAffinities.isDisjoint(with: affix.keywords)
            })
        }
    }

    @Test func `Scarfeast keeps fixed Leech behavior at both rarities`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "scarfeast"))
        #expect(affix.keywords == Set([.physical, .leech, .health]))
        #expect(affix.basic.triggers.physicalAttackLeechBelowHalfHealth)
        #expect(affix.astral.triggers.physicalAttackLeechBelowHalfHealth)
        #expect(affix.basic.description == "Physical attacks gain Leech while you're below half Health")
    }
}
