import Testing
import TrinketContent
import TrinketCore

struct ItemGeneratorTests {
    @Test(arguments: [
        (baseTypeID: "longsword", rarity: Rarity.basic, range: 1 ... 2),
        (baseTypeID: "ruby_ring", rarity: .astral, range: 3 ... 4),
    ])
    func itemsRollAffixCountsInRarityRange(
        baseTypeID: String,
        rarity: Rarity,
        range: ClosedRange<Int>
    ) throws {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == baseTypeID })
        let counts = generatedAffixCounts(baseType: baseType, rarity: rarity, seedRange: 1 ... 120)

        try #expect(counts.allSatisfy { range.contains($0) })
        try #expect(counts.contains(range.lowerBound))
        try #expect(counts.contains(range.upperBound))
    }

    @Test func generatedItemsDoNotDuplicateAffixes() throws {
        let baseType = try ItemFixtures.baseType("plate_armor")
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
        let baseType = try ItemFixtures.baseType("plate_armor")
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
        for baseType in GameContent.itemBaseTypes where baseType.slot != .trinket {
            let eligibleAffixes = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }

            try #expect(eligibleAffixes.count >= 4, "\(baseType.id)")
        }
    }

    @Test func trinketsAreAuthoredAstralSingletons() throws {
        let trinkets = GameContent.trinketItems

        try #expect(!trinkets.isEmpty)
        for item in trinkets {
            try #expect(item.isTrinket)
            try #expect(item.rarity == .astral)
            try #expect(item.id == item.baseType.id)
            try #expect(item.templateID == item.baseType.id)
            try #expect(item.affixes.count == 1)
            try #expect(item.affixes[0].id == item.baseType.id)
            try #expect(!item.affixes[0].description.isEmpty)
            try #expect((1 ... 2).contains(item.keywords.count))
            try #expect(item.keywords == item.baseType.keywordAffinities)
        }
    }

    @Test func trinketTierAlwaysYieldsAnUnownedTrinketWhenPoolRemains() throws {
        let rewards = (1 ... 40).map { seed in
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: UInt64(seed))
            return ItemRewardGenerator.generate(
                id: "reward-\(seed)",
                tier: .trinket,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                using: &randomNumberGenerator
            )
        }

        try #expect(rewards.allSatisfy { $0.isTrinket && GameContent.trinketItems.contains($0) })
    }

    @Test func uniqueTierYieldsCatalogUniquesAndDegradesToTrinketsWhenOwned() throws {
        let uniques = (1 ... 12).map { seed in
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: UInt64(seed))
            return ItemRewardGenerator.generate(
                id: "unique-\(seed)",
                tier: .unique,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                using: &randomNumberGenerator
            )
        }
        try #expect(uniques.allSatisfy { GameContent.uniqueItems.contains($0) })

        let allOwned = Set(GameContent.uniqueItems.map(\.templateID))
        var degradedGenerator = SeededRandomNumberGenerator(seed: 7)
        let degraded = ItemRewardGenerator.generate(
            id: "degraded",
            tier: .unique,
            ownedTrinketIDs: [],
            ownedUniqueIDs: allOwned,
            using: &degradedGenerator
        )
        try #expect(degraded.isTrinket)
    }

    @Test func astralRewardsExcludeOwnedAndKeywordIneligibleTrinkets() throws {
        let poisonTrinketIDs = Set(GameContent.trinketItems.filter {
            $0.keywords.contains(.poison)
        }.map(\.templateID))

        for seed in UInt64(1) ... 16 {
            var biasedRandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let biasedReward = ItemRewardGenerator.generate(
                id: "poison-\(seed)",
                tier: .trinket,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                keywordBias: [.poison],
                using: &biasedRandomNumberGenerator
            )
            if biasedReward.isTrinket {
                try #expect(poisonTrinketIDs.contains(biasedReward.templateID))
            }

            var exhaustedRandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let exhaustedReward = ItemRewardGenerator.generate(
                id: "exhausted-\(seed)",
                tier: .trinket,
                ownedTrinketIDs: poisonTrinketIDs,
                ownedUniqueIDs: [],
                keywordBias: [.poison],
                using: &exhaustedRandomNumberGenerator
            )
            try #expect(!exhaustedReward.isTrinket)
        }
    }

    @Test func seededGenerationIsReproducible() throws {
        let baseType = try ItemFixtures.baseType("emerald_ring")
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
            if definition.slot == .trinket {
                continue
            }
            // Trigger-only affixes may share identical basic/astral power tables.
            let isTriggerOnly = definition.basic.modifiers.isEmpty && definition.astral.modifiers.isEmpty
            if isTriggerOnly {
                continue
            }
            try #expect(definition.basic != definition.astral, "\(definition.id)")
        }
    }

    @Test func guaranteedAffixIDsAreAlwaysIncluded() throws {
        let baseType = try ItemFixtures.baseType("sapphire_ring")
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

    @Test func generatedItemsPersistRolledAffixPowersInRarityRange() throws {
        let baseType = try ItemFixtures.baseType("longsword")
        for seed in UInt64(1) ... 40 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let item = ItemGenerator().generate(
                id: "rolled-\(seed)",
                baseType: baseType,
                rarity: .basic,
                using: &rng
            )
            let powers = try #require(item.affixPowers)
            try #expect(powers.count == item.affixes.count)
            for (index, affix) in item.affixes.enumerated() {
                let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                let catalog = definition.power(for: .basic)
                let stored = powers[index]
                if definition.basic == definition.astral {
                    try #expect(stored == catalog)
                    try #expect(!item.isPerfectAffix(at: index))
                    continue
                }
                for (catalogModifier, storedModifier) in zip(catalog.modifiers, stored.modifiers) {
                    if catalogModifier.isPercent {
                        let allowed = ItemAffixMagnitudeRoll.percentValues(around: catalogModifier.numericValue)
                        try #expect(allowed.contains { abs($0 - storedModifier.numericValue) < 1e-9 })
                    } else {
                        let range = ItemAffixMagnitudeRoll.integerRange(
                            around: Int(catalogModifier.numericValue.rounded())
                        )
                        try #expect(range.contains(Int(storedModifier.numericValue.rounded())))
                    }
                }
                let isPerfect = item.isPerfectAffix(at: index)
                try #expect(isPerfect == stored.isAtOrAboveRollMax(of: catalog))
            }
        }
    }

    @Test func mysteryItemRarityRollsBasicEightyPercent() throws {
        var basicCount = 0
        for seed in UInt64(1) ... 24 {
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            if MysteryItemRarity.roll(using: &randomNumberGenerator) == .basic {
                basicCount += 1
            }
        }
        try #expect((14 ... 22).contains(basicCount))
    }

    @Test func mysteryItemRarityNeverRollsUniqueTier() {
        // Mystery rewards promise an authored base type and affixes; the Unique
        // tier would silently discard both, so its band folds into Astral.
        for seed in UInt64(1) ... 50 {
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let tier = MysteryItemRarity.roll(astralChanceBonusPercent: 50, using: &randomNumberGenerator)
            #expect(tier != .unique)
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
