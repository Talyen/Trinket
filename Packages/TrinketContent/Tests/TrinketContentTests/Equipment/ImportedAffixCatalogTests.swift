import Testing
import TrinketContent
import TrinketCore

struct ImportedAffixCatalogTests {
    @Test func `supported affixes resolve Basic and Astral powers`() throws {
        let thornwrought = try #require(GameContent.itemAffixDefinition(matching: "thornwrought"))
        let barbed = try #require(GameContent.itemAffixDefinition(matching: "barbed"))
        let briarward = try #require(GameContent.itemAffixDefinition(matching: "briarward"))
        let bloodward = try #require(GameContent.itemAffixDefinition(matching: "bloodward"))

        #expect(thornwrought.basic.triggers.startBattleThorns == 1)
        #expect(thornwrought.astral.triggers.startBattleThorns == 3)
        #expect(barbed.basic.triggers.thornsDamageFlat == 1)
        #expect(barbed.astral.triggers.thornsDamageFlat == 3)
        #expect(briarward.basic.triggers.blockBrokenThornsFlat == 2)
        #expect(briarward.astral.triggers.blockBrokenThornsFlat == 4)
        #expect(bloodward.basic.triggers.leechBlockChancePercent == 0.10)
        #expect(bloodward.astral.triggers.leechBlockChancePercent == 0.20)
        #expect(bloodward.astral.description == "Leech has a 20% chance to also grant an equal amount of Block.")
        #expect(thornwrought.keywords.contains(.thorns))

        for affix in [thornwrought, barbed, briarward, bloodward] {
            #expect(GameContent.itemBaseTypes.contains { base in
                base.slot == affix.slot && !base.keywordAffinities.isDisjoint(with: affix.keywords)
            })
        }
    }
}
