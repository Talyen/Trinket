import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ItemGeneratorTests {
    @Test(arguments: [
        ("longsword", Rarity.basic, 1, 1), ("plate_armor", .basic, 80, 1),
        ("ruby_ring", .basic, 81, 2), ("longsword", .basic, 100, 2),
        ("plate_armor", .astral, 1, 3), ("ruby_ring", .astral, 75, 3),
        ("longsword", .astral, 76, 4), ("plate_armor", .astral, 100, 4),
    ])
    func `generated gear respects count boundaries eligibility uniqueness and rolled powers`(
        countCase: (String, Rarity, Int, Int),
    ) throws {
        let (baseTypeID, rarity, countRoll, expectedCount) = countCase
        let baseType = try ItemFixtures.baseType(baseTypeID)
        // Find only the primitive RNG draw; the real generator must apply the
        // rarity threshold and retain every selected power on the saved item.
        let matchingSeed = (UInt64(1) ... 10000).first { seed in
            var probe = SeededRandomNumberGenerator(seed: seed)
            return Int.random(in: 1 ... 100, using: &probe) == countRoll
        }
        let seed = try #require(matchingSeed)
        var rng = SeededRandomNumberGenerator(seed: seed)
        let item = ItemGenerator().generate(
            id: "rolled-\(seed)", baseType: baseType, rarity: rarity, using: &rng,
        )
        try #expect(item.affixes.count == expectedCount)
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
            if !catalog.hasRollableMagnitudes {
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

        var biasedRandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let biasedReward = ItemRewardGenerator.generate(
            id: "poison",
            rewardLevel: 1,
            allowedTiers: [.trinket],
            ownedTrinketIDs: [],
            ownedUniqueIDs: [],
            keywordBias: [.poison],
            using: &biasedRandomNumberGenerator,
        )
        try #expect(biasedReward.isTrinket)
        try #expect(poisonTrinketIDs.contains(biasedReward.templateID))

        var exhaustedRandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let exhaustedReward = ItemRewardGenerator.generate(
            id: "exhausted",
            rewardLevel: 1,
            allowedTiers: [.basic, .trinket],
            ownedTrinketIDs: poisonTrinketIDs,
            ownedUniqueIDs: [],
            keywordBias: [.poison],
            using: &exhaustedRandomNumberGenerator,
        )
        try #expect(!exhaustedReward.isTrinket)
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

    @Test func `unrestricted collectible pools preserve selection and random state`() {
        for tier in [ItemDropTier.trinket, .unique] {
            for seed in 0 ..< 20 {
                var unrestricted = SeededRandomNumberGenerator(seed: UInt64(seed))
                var explicit = unrestricted
                let first = ItemRewardGenerator.generate(
                    id: "reward", rewardLevel: 1, allowedTiers: [tier],
                    ownedTrinketIDs: [], ownedUniqueIDs: [], using: &unrestricted,
                )
                let second = ItemRewardGenerator.generate(
                    id: "reward", rewardLevel: 1, allowedTiers: [tier],
                    ownedTrinketIDs: [], ownedUniqueIDs: [],
                    eligibleTrinketIDs: Set(GameContent.trinketItems.lazy.map(\.templateID)),
                    eligibleUniqueIDs: Set(GameContent.uniqueItems.lazy.map(\.templateID)),
                    using: &explicit,
                )
                #expect(first == second)
                #expect(unrestricted == explicit)
            }
        }
    }
}
