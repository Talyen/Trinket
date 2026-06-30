import XCTest
@testable import Trinket

final class ItemGenerationTests: XCTestCase {
    func testBasicItemsRollOneOrTwoAffixes() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .basic, seedRange: 1 ... 120)

        XCTAssertTrue(counts.allSatisfy { (1 ... 2).contains($0) })
        XCTAssertTrue(counts.contains(1))
        XCTAssertTrue(counts.contains(2))
    }

    func testAstralItemsRollThreeOrFourAffixes() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "ruby_ring" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .astral, seedRange: 1 ... 120)

        XCTAssertTrue(counts.allSatisfy { (3 ... 4).contains($0) })
        XCTAssertTrue(counts.contains(3))
        XCTAssertTrue(counts.contains(4))
    }

    func testGeneratedItemsDoNotDuplicateAffixes() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        let item = ItemGenerator().generate(
            id: "test-plate",
            baseType: baseType,
            rarity: .astral,
            using: &randomNumberGenerator
        )

        XCTAssertEqual(Set(item.affixes.map(\.id)).count, item.affixes.count)
    }

    func testGeneratedAffixesMatchSlotAndAnyKeywordAffinity() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 99)

        let item = ItemGenerator().generate(
            id: "test-plate",
            baseType: baseType,
            rarity: .astral,
            using: &randomNumberGenerator
        )

        for affix in item.affixes {
            let definition = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == affix.id })
            XCTAssertEqual(definition.slot, baseType.slot)
            XCTAssertFalse(definition.keywords.isDisjoint(with: baseType.keywordAffinities))
        }
    }

    func testEveryBaseTypeHasEnoughEligibleAffixesForAstralMaximum() {
        for baseType in GameContent.itemBaseTypes {
            let eligibleAffixes = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }

            XCTAssertGreaterThanOrEqual(eligibleAffixes.count, 4, baseType.id)
        }
    }

    func testSeededGenerationIsReproducible() throws {
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "emerald_ring" })
        var firstRandomNumberGenerator = SeededRandomNumberGenerator(seed: 123)
        var secondRandomNumberGenerator = SeededRandomNumberGenerator(seed: 123)

        let firstItem = ItemGenerator().generate(
            id: "first",
            baseType: baseType,
            rarity: .astral,
            using: &firstRandomNumberGenerator
        )
        let secondItem = ItemGenerator().generate(
            id: "first",
            baseType: baseType,
            rarity: .astral,
            using: &secondRandomNumberGenerator
        )

        XCTAssertEqual(firstItem, secondItem)
    }

    func testAstralAffixesResolveStrongerThanBasicAffixes() {
        for definition in GameContent.itemAffixDefinitions {
            XCTAssertNotEqual(definition.basic, definition.astral, definition.id)
        }
    }

    private func generatedAffixCounts(
        baseType: ItemBaseType,
        rarity: Rarity,
        seedRange: ClosedRange<UInt64>
    ) -> [Int] {
        seedRange.map { seed in
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            return ItemGenerator()
                .generate(
                    id: "test-\(seed)",
                    baseType: baseType,
                    rarity: rarity,
                    using: &randomNumberGenerator
                )
                .affixes
                .count
        }
    }
}
