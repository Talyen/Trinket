import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct BattleLootTests {
    @Test func quantityRangeEndpoints() {
        #expect(BattleLoot.quantityRange(forLevel: 1) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 24) == 7 ... 13)
        #expect(BattleLoot.quantityRange(forLevel: 48) == 11 ... 23)
        #expect(BattleLoot.quantityRange(forLevel: 50) == 12 ... 24)
    }

    @Test func resolveAlwaysGrantsOneItemTwoDistinctMaterialsAndGold() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        let package = BattleLoot.resolve(
            encounterLevel: 1,
            enemyIsBoss: false,
            itemID: "test-loot",
            using: &rng
        )
        #expect(package.item.id == "test-loot")
        #expect(package.item.rarity == .basic)
        #expect((3 ... 4).contains(package.gold))
        #expect(package.materials.count == 2)
        #expect(Set(package.materials.map(\.resource)).count == 2)
        for material in package.materials {
            #expect(BattleLoot.materialResources.contains(material.resource))
            #expect((3 ... 4).contains(material.quantity))
        }
    }

    @Test func bossGrantsAstralAndDoublesCurrency() {
        var rng = SeededRandomNumberGenerator(seed: 99)
        let package = BattleLoot.resolve(
            encounterLevel: 1,
            enemyIsBoss: true,
            itemID: "boss-loot",
            using: &rng
        )
        #expect(package.item.rarity == .astral)
        #expect((6 ... 8).contains(package.gold))
        for material in package.materials {
            #expect((6 ... 8).contains(material.quantity))
        }
    }

    @Test func journeyLootIsSeedStable() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let first = BattleLoot.resolveJourney(stage: stage, encounterLevel: 1, enemyIsBoss: false)
        let second = BattleLoot.resolveJourney(stage: stage, encounterLevel: 1, enemyIsBoss: false)
        #expect(first == second)
        #expect(first.item.rarity == .basic)
    }

    @Test func bossJourneyLootIsAstral() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-10"))
        let package = BattleLoot.resolveJourney(stage: stage, encounterLevel: 5, enemyIsBoss: true)
        #expect(package.item.rarity == .astral)
    }

    @Test func homesteadAstralChanceAppliesToJourneyAndSpireBattleLoot() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let journeyLoot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false,
            astralChanceBonusPercent: 100
        )
        #expect(journeyLoot.item.rarity == .astral)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let spireLoot = SpireCompletion.resolveLoot(
            for: floor,
            astralChanceBonusPercent: 100
        )
        #expect(spireLoot.item.rarity == .astral)
    }
}
