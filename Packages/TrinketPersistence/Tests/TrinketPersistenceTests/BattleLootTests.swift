import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct BattleLootTests {
    @Test func quantityRangeEndpoints() {
        #expect(BattleLoot.quantityRange(forLevel: 1) == 8 ... 12)
        #expect(BattleLoot.quantityRange(forLevel: 24) == 10 ... 18)
        #expect(BattleLoot.quantityRange(forLevel: 48) == 12 ... 24)
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
        #expect((8 ... 12).contains(package.gold))
        #expect(package.materials.count == 2)
        #expect(Set(package.materials.map(\.resource)).count == 2)
        for material in package.materials {
            #expect(BattleLoot.materialResources.contains(material.resource))
            #expect((8 ... 12).contains(material.quantity))
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
        #expect((16 ... 24).contains(package.gold))
        for material in package.materials {
            #expect((16 ... 24).contains(material.quantity))
        }
    }

    @Test func journeyLootIsSeedStable() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let first = BattleLoot.resolveJourney(stage: stage, encounterLevel: 1, enemyIsBoss: false)
        let second = BattleLoot.resolveJourney(stage: stage, encounterLevel: 1, enemyIsBoss: false)
        #expect(first == second)
        #expect(first.item.rarity == .basic)
        #expect(first.item.displayName == "Leather Armor")
        #expect(first.item.templateID == "leather_armor-basic")
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

    @Test func completingBattleStageGrantsBattleLootOnce() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let loot = BattleLoot.resolveJourney(stage: stage, encounterLevel: 1, enemyIsBoss: false)
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .initial,
            inventory: PlayerInventoryState(items: []),
            homestead: .freshStart
        )

        StageCompletion.complete(
            stage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 4,
            loot: loot,
            in: GameContent.chapters,
            save: &save
        )

        #expect(save.roster.gold == loot.gold + 4)
        #expect(save.inventory.item(matching: loot.item.id) != nil)
        #expect(save.journey.hasClaimedRewards(for: stage))
        for material in loot.materials {
            #expect(save.homestead.resources[material.resource, default: 0] == material.quantity)
        }

        let goldAfterFirst = save.roster.gold
        StageCompletion.complete(
            stage,
            hero: hero,
            companion: companion,
            battleEarnedGold: 2,
            loot: loot,
            in: GameContent.chapters,
            save: &save
        )
        #expect(save.roster.gold == goldAfterFirst + 2)
        #expect(save.inventory.items.filter { $0.id == loot.item.id }.count == 1)
    }
}
