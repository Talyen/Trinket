import Testing
import TrinketContent
import TrinketCore

struct ItemGeneratorTests {
    @Test func basicItemsRollOneOrTwoAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .basic, seedRange: 1 ... 120)

        try #expect(counts.allSatisfy { (1 ... 2).contains($0) })
        try #expect(counts.contains(1))
        try #expect(counts.contains(2))
    }

    @Test func astralItemsRollThreeOrFourAffixes() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "ruby_ring" })
        let counts = generatedAffixCounts(baseType: baseType, rarity: .astral, seedRange: 1 ... 120)

        try #expect(counts.allSatisfy { (3 ... 4).contains($0) })
        try #expect(counts.contains(3))
        try #expect(counts.contains(4))
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

        try #expect(Set(item.affixes.map(\.id)).count == item.affixes.count)
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
            try #expect(definition.slot == baseType.slot)
            try #expect(!(definition.keywords.isDisjoint(with: baseType.keywordAffinities)))
        }
    }

    @Test func everyBaseTypeHasEnoughEligibleAffixesForAstralMaximum() throws {
        for baseType in GameContent.itemBaseTypes {
            let eligibleAffixes = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }

            try #expect(eligibleAffixes.count >= 4, "\(baseType.id)")
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

        try #expect(firstItem == secondItem)
    }

    @Test func astralAffixesResolveStrongerThanBasicAffixes() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(definition.basic != definition.astral, "\(definition.id)")
        }
    }

    @Test func guaranteedAffixIDsAreAlwaysIncluded() throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "sapphire_ring" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        let item = ItemGenerator().generate(
            id: "mana-ring",
            baseType: baseType,
            rarity: .basic,
            guaranteedAffixIDs: ["manabound"],
            using: &randomNumberGenerator
        )

        try #expect(item.affixes.contains { $0.id == "manabound" })
        try #expect(item.affixes.count >= 1)
    }

    @Test func mysteryItemRarityRollsBasicEightyPercent() throws {
        var basicCount = 0
        for seed in UInt64(1) ... 200 {
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            if MysteryItemRarity.roll(using: &randomNumberGenerator) == .basic {
                basicCount += 1
            }
        }
        try #expect((140 ... 180).contains(basicCount))
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
