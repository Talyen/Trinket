import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ItemGeneratorTests {
    @Test(arguments: ["longsword", "plate_armor", "ruby_ring"], [Rarity.basic, .astral])
    func `generated gear respects rarity eligibility uniqueness and rolled powers`(
        baseTypeID: String,
        rarity: Rarity,
    ) throws {
        let baseType = try ItemFixtures.baseType(baseTypeID)
        let range = rarity == .basic ? 1 ... 2 : 3 ... 4
        var counts = Set<Int>()
        for seed in UInt64(1) ... 24 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let item = ItemGenerator().generate(
                id: "rolled-\(seed)", baseType: baseType, rarity: rarity, using: &rng,
            )
            counts.insert(item.affixes.count)
            try #expect(range.contains(item.affixes.count))
            try #expect(Set(item.affixes.map(\.id)).count == item.affixes.count)
            for affix in item.affixes {
                let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                try #expect(definition.slot == baseType.slot)
                try #expect(!definition.keywords.isDisjoint(with: baseType.keywordAffinities))
            }
            let powers = try #require(item.affixPowers)
            try #expect(powers.count == item.affixes.count)
            for (index, affix) in item.affixes.enumerated() {
                let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                let catalog = definition.power(for: rarity)
                let stored = powers[index]
                if definition.basic == definition.astral {
                    try #expect(stored == catalog)
                    try #expect(!item.isPerfectAffix(at: index))
                    continue
                }
                try #expect(stored.modifiers.count == catalog.modifiers.count)
                for (catalogModifier, storedModifier) in zip(catalog.modifiers, stored.modifiers) {
                    if catalogModifier.isPercent {
                        let allowed = ItemAffixMagnitudeRoll.percentValues(around: catalogModifier.numericValue)
                        try #expect(allowed.contains { abs($0 - storedModifier.numericValue) < 1e-9 })
                    } else {
                        let range = ItemAffixMagnitudeRoll.integerRange(
                            around: Int(catalogModifier.numericValue.rounded()),
                        )
                        try #expect(range.contains(Int(storedModifier.numericValue.rounded())))
                    }
                }
                let isPerfect = item.isPerfectAffix(at: index)
                try #expect(isPerfect == stored.isAtOrAboveRollMax(of: catalog))
            }
        }
        try #expect(counts.contains(range.lowerBound))
        try #expect(counts.contains(range.upperBound))
    }

    @Test func `fixed affix count override pins count`() throws {
        let baseType = try ItemFixtures.baseType("longsword")
        var rng = SeededRandomNumberGenerator(seed: 12)

        let item = ItemGenerator().generate(
            id: "fixed",
            baseType: baseType,
            rarity: .basic,
            fixedAffixCount: 1,
            keywordBias: [.physical],
            using: &rng,
        )

        try #expect(item.affixes.count == 1)
    }

    @Test func `every base type has enough eligible affixes for astral maximum`() throws {
        for baseType in GameContent.itemBaseTypes where baseType.slot != .trinket {
            let eligibleAffixes = ItemFixtures.eligibleAffixes(forBaseType: baseType)

            try #expect(eligibleAffixes.count >= 4, "\(baseType.id)")
        }
    }

    @Test func `trinkets are authored astral singletons`() throws {
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

    @Test(arguments: [ItemDropTier.trinket, .unique])
    func `catalog rewards exclude owned items before rolling`(tier: ItemDropTier) throws {
        let pool = tier == .trinket ? GameContent.trinketItems : GameContent.uniqueItems
        let remaining = try #require(pool.last)
        let owned = Set(pool.dropLast().map(\.templateID))
        try #require(!owned.isEmpty)
        for ownedIDs in [Set<String>(), owned] {
            var rng = SeededRandomNumberGenerator(seed: 7)
            let reward = ItemRewardGenerator.generate(
                id: "catalog-reward", rewardLevel: 1, allowedTiers: [tier],
                ownedTrinketIDs: tier == .trinket ? ownedIDs : [],
                ownedUniqueIDs: tier == .unique ? ownedIDs : [],
                using: &rng,
            )
            try #expect(pool.contains(reward))
            try #expect(!ownedIDs.contains(reward.templateID))
            if !ownedIDs.isEmpty {
                try #expect(reward == remaining)
            }
        }
    }

    @Test func `exhausted unique pool degrades to an allowed gear tier`() throws {
        let allOwned = Set(GameContent.uniqueItems.map(\.templateID))
        var degradedGenerator = SeededRandomNumberGenerator(seed: 7)
        let degraded = ItemRewardGenerator.generate(
            id: "degraded",
            rewardLevel: 1,
            allowedTiers: [.basic, .unique],
            ownedTrinketIDs: [],
            ownedUniqueIDs: allOwned,
            using: &degradedGenerator,
        )
        try #expect(degraded.rarity == .basic)
    }

    @Test(arguments: [false, true])
    func `exhausted trinket only pool degrades to basic gear`(trinketOnlyBases: Bool) throws {
        let bases = trinketOnlyBases
            ? GameContent.itemBaseTypes.filter { $0.slot == .trinket }
            : GameContent.itemBaseTypes
        try #require(!bases.isEmpty)
        let allOwned = Set(GameContent.trinketItems.map(\.templateID))
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let degraded = ItemRewardGenerator.generate(
            id: "degraded-trinket",
            rewardLevel: 1,
            allowedTiers: [.trinket],
            ownedTrinketIDs: allOwned,
            ownedUniqueIDs: [],
            baseTypes: bases,
            using: &randomNumberGenerator,
        )
        try #expect(degraded.rarity == .basic)
        try #expect(degraded.baseType.slot != .trinket)
    }

    @Test func `astral rewards exclude owned and keyword ineligible trinkets`() throws {
        let poisonTrinketIDs = Set(GameContent.trinketItems.filter {
            $0.keywords.contains(.poison)
        }.map(\.templateID))
        try #require(!poisonTrinketIDs.isEmpty)

        for seed in UInt64(1) ... 16 {
            var biasedRandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let biasedReward = ItemRewardGenerator.generate(
                id: "poison-\(seed)",
                rewardLevel: 1,
                allowedTiers: [.trinket],
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                keywordBias: [.poison],
                using: &biasedRandomNumberGenerator,
            )
            try #expect(biasedReward.isTrinket)
            try #expect(poisonTrinketIDs.contains(biasedReward.templateID))

            var exhaustedRandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let exhaustedReward = ItemRewardGenerator.generate(
                id: "exhausted-\(seed)",
                rewardLevel: 1,
                allowedTiers: [.basic, .trinket],
                ownedTrinketIDs: poisonTrinketIDs,
                ownedUniqueIDs: [],
                keywordBias: [.poison],
                using: &exhaustedRandomNumberGenerator,
            )
            try #expect(!exhaustedReward.isTrinket)
        }
    }

    @Test func `seeded generation is reproducible`() throws {
        let baseType = try ItemFixtures.baseType("emerald_ring")
        var firstRandomNumberGenerator = SeededRandomNumberGenerator(seed: 123)
        var secondRandomNumberGenerator = SeededRandomNumberGenerator(seed: 123)

        let firstItem = ItemGenerator().generate(
            id: "first",
            baseType: baseType,
            rarity: .astral,
            using: &firstRandomNumberGenerator,
        )
        let secondItem = ItemGenerator().generate(
            id: "first",
            baseType: baseType,
            rarity: .astral,
            using: &secondRandomNumberGenerator,
        )

        try #expect(firstItem == secondItem)
    }

    @Test func `repeated guarantees reserve one affix and leave room for other rolls`() throws {
        let baseType = try ItemFixtures.baseType("sapphire_ring")
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        let item = ItemGenerator().generate(
            id: "mana-ring",
            baseType: baseType,
            rarity: .basic,
            fixedAffixCount: 2,
            guaranteedAffixIDs: ["manabound", "manabound"],
            using: &randomNumberGenerator,
        )

        #expect(item.affixes.count == 2)
        #expect(item.affixes.count(where: { $0.id == "manabound" }) == 1)
        #expect(Set(item.affixes.map(\.id)).count == 2)
    }

    @Test func `repeat template drops from one stage keep distinct identities`() throws {
        let template = try #require(GameContent.sampleInventoryItems.first)
        try #require(!template.isTrinket && template.rarity != .unique)
        let first = template.rewardInstance(for: "chapter-1-stage-1")
        let second = template.rewardInstance(for: "chapter-1-stage-1", dropIndex: 1)

        try #expect(first.id != second.id)
        #expect(first.templateID == second.templateID)
        #expect(template.rewardInstance(for: "chapter-1-stage-1") == first)
    }

    @Test func `explicit pools exclude unavailable categories without promoting gear`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "flail"))
        var rng = SeededRandomNumberGenerator(seed: 1)
        let eligible = ItemRewardGenerator.generate(
            id: "ward-offer",
            rewardLevel: 1,
            allowedTiers: [.unique],
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            eligibleTrinketIDs: ["bone_charm"],
            eligibleUniqueIDs: ["wardbreaker"],
            fallbackBaseType: base,
            using: &rng,
        )
        #expect(eligible.templateID == "wardbreaker")
        let fallback = ItemRewardGenerator.generate(
            id: "ward-fallback",
            rewardLevel: 1,
            allowedTiers: [.basic, .unique],
            ownedTrinketIDs: [],
            ownedUniqueIDs: ["wardbreaker"],
            eligibleTrinketIDs: ["bone_charm"],
            eligibleUniqueIDs: ["wardbreaker"],
            fallbackBaseType: base,
            using: &rng,
        )
        #expect(fallback.baseType.id == "flail")
        #expect(fallback.rarity == .basic)
    }
}
