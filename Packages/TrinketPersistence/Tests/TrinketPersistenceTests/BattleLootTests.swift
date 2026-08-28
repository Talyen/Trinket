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
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            using: &rng
        )
        let isCatalogIdentity = package.item.isTrinket || package.item.rarity == .unique
        #expect(isCatalogIdentity || package.item.id == "test-loot")
        if !isCatalogIdentity {
            #expect(package.item.rarity == .basic || package.item.rarity == .astral)
        }
        #expect((3 ... 4).contains(package.gold))
        #expect(package.materials.count == 2)
        #expect(Set(package.materials.map(\.resource)).count == 2)
        for material in package.materials {
            #expect(BattleLoot.materialResources.contains(material.resource))
            #expect((3 ... 4).contains(material.quantity))
        }
    }

    @Test func bossGrantsSpecialTierAndDoublesCurrency() {
        var rng = SeededRandomNumberGenerator(seed: 99)
        let package = BattleLoot.resolve(
            encounterLevel: 1,
            enemyIsBoss: true,
            itemID: "boss-loot",
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            using: &rng
        )
        switch package.item.rarity {
        case .unique, .astral:
            break
        case .basic:
            Issue.record("Boss loot must never be Basic")
        }
        #expect((6 ... 8).contains(package.gold))
        for material in package.materials {
            #expect((6 ... 8).contains(material.quantity))
        }
    }

    private static let ladderDraws: UInt64 = 100

    @Test func normalDropLadderMatchesAuthoredBands() {
        var uniqueCount = 0
        var trinketCount = 0
        var astralCount = 0
        var basicCount = 0
        for seed in UInt64(0) ..< Self.ladderDraws {
            var rng = SeededRandomNumberGenerator(seed: seed)
            switch ItemRarityRoll.roll(bossContent: false, using: &rng) {
            case .unique: uniqueCount += 1
            case .trinket: trinketCount += 1
            case .astral: astralCount += 1
            case .basic: basicCount += 1
            }
        }
        #expect((1 ... 12).contains(uniqueCount))
        #expect((2 ... 15).contains(trinketCount))
        #expect((2 ... 16).contains(astralCount))
        #expect(basicCount >= 65)
    }

    @Test func bossDropLadderMatchesAuthoredBands() {
        var uniqueCount = 0
        var trinketCount = 0
        var astralCount = 0
        for seed in UInt64(0) ..< Self.ladderDraws {
            var rng = SeededRandomNumberGenerator(seed: seed)
            switch ItemRarityRoll.roll(bossContent: true, using: &rng) {
            case .unique: uniqueCount += 1
            case .trinket: trinketCount += 1
            case .astral: astralCount += 1
            case .basic: Issue.record("Boss ladder never yields Basic")
            }
        }
        #expect((18 ... 43).contains(uniqueCount))
        #expect((18 ... 43).contains(trinketCount))
        #expect((27 ... 54).contains(astralCount))
    }

    @Test func disallowingUniquesFoldsTheirBandIntoAstral() {
        var uniqueAllowed = 0
        var trinketAllowed = 0
        var astralAllowed = 0
        var trinketFolded = 0
        var astralFolded = 0
        for seed in UInt64(0) ..< Self.ladderDraws {
            var allowedRng = SeededRandomNumberGenerator(seed: seed)
            switch ItemRarityRoll.roll(bossContent: false, using: &allowedRng) {
            case .unique: uniqueAllowed += 1
            case .trinket: trinketAllowed += 1
            case .astral: astralAllowed += 1
            case .basic: break
            }

            var foldedRng = SeededRandomNumberGenerator(seed: seed)
            switch ItemRarityRoll.roll(bossContent: false, allowsUnique: false, using: &foldedRng) {
            case .unique:
                Issue.record("allowsUnique: false must never yield Unique")
            case .trinket: trinketFolded += 1
            case .astral: astralFolded += 1
            case .basic: break
            }
        }
        #expect(trinketFolded == trinketAllowed)
        #expect(astralFolded == astralAllowed + uniqueAllowed)
        #expect(uniqueAllowed > 0)
    }

    @Test func journeyLootIsSeedStable() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let first = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 8,
            ownedTrinketIDs: [],
            ownedUniqueIDs: []
        )
        let second = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 8,
            ownedTrinketIDs: [],
            ownedUniqueIDs: []
        )
        #expect(first == second)

        let otherWorld = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 9,
            ownedTrinketIDs: [],
            ownedUniqueIDs: []
        )
        #expect(first != otherWorld)
    }

    @Test func bossJourneyLootIsNeverBasic() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-10"))
        let package = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 5,
            enemyIsBoss: true,
            worldSeed: 8,
            ownedTrinketIDs: [],
            ownedUniqueIDs: []
        )
        switch package.item.rarity {
        case .unique, .astral:
            break
        case .basic:
            Issue.record("Boss loot must never be Basic")
        }
    }

    @Test func homesteadAstralChanceAppliesToJourneyAndSpireBattleLoot() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        let journeyLoot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: 1,
            enemyIsBoss: false,
            worldSeed: 8,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            astralChanceBonusPercent: 100
        )
        #expect(journeyLoot.item.rarity == .astral)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let spireLoot = SpireCompletion.resolveLoot(
            for: floor,
            worldSeed: 8,
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            astralChanceBonusPercent: 100
        )
        #expect(spireLoot.item.rarity == .astral)
    }
}
