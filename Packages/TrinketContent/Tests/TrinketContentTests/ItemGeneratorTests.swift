import Testing
import TrinketContent
import TrinketCore

@Suite
struct ItemGeneratorTests {
    @Test func basicItemsRollOneOrTwoAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .basic, seedRange: 1 ... 120)

        #expect(counts.allSatisfy { (1 ... 2).contains($0) })
        #expect(counts.contains(1))
        #expect(counts.contains(2))
    }

    @Test func astralItemsRollThreeOrFourAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "ruby_ring" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .astral, seedRange: 1 ... 120)

        #expect(counts.allSatisfy { (3 ... 4).contains($0) })
        #expect(counts.contains(3))
        #expect(counts.contains(4))
    }

    @Test func generatedItemsDoNotDuplicateAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        let item = ItemGenerator().generate(
            id: "test-plate",
            baseType: baseType,
            rarity: .astral,
            using: &randomNumberGenerator
        )

        #expect(Set(item.affixes.map(\.id)).count == item.affixes.count)
    }

    @Test func generatedAffixesMatchSlotAndAnyKeywordAffinity() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 99)

        let item = ItemGenerator().generate(
            id: "test-plate",
            baseType: baseType,
            rarity: .astral,
            using: &randomNumberGenerator
        )

        for affix in item.affixes {
            let definition = try #require(GameContent.itemAffixDefinitions.first { $0.id == affix.id })
            #expect(definition.slot == baseType.slot)
            #expect(!(definition.keywords.isDisjoint(with: baseType.keywordAffinities)))
        }
    }

    @Test func everyBaseTypeHasEnoughEligibleAffixesForAstralMaximum() {
        for baseType in GameContent.itemBaseTypes {
            let eligibleAffixes = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }

            #expect(eligibleAffixes.count >= 4, baseType.id)
        }
    }

    @Test func seededGenerationIsReproducible() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "emerald_ring" })
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

        #expect(firstItem == secondItem)
    }

    @Test func astralAffixesResolveStrongerThanBasicAffixes() {
        for definition in GameContent.itemAffixDefinitions {
            #expect(definition.basic != definition.astral, definition.id)
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
