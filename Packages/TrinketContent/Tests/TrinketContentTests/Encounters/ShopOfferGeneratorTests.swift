import Testing
import TrinketContent
import TrinketCore

struct ShopOfferGeneratorTests {
    @Test func `same seed produces identical offers`() {
        var first = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 7, forStageID: "chapter-2-stage-8"),
        )
        var second = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 7, forStageID: "chapter-2-stage-8"),
        )

        let firstOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", rewardLevel: 6, using: &first)
        let secondOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", rewardLevel: 6, using: &second)

        #expect(firstOffers.count == ShopOfferGenerator.offerCount)
        #expect(Set(firstOffers.map(\.id)).count == firstOffers.count)
        #expect(Set(firstOffers.map(\.item.id)).count == firstOffers.count)
        #expect(firstOffers == secondOffers)
    }

    @Test func `empty base types yield no offers`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "empty",
            rewardLevel: 6,
            baseTypes: [],
            using: &randomNumberGenerator,
        )
        #expect(offers.isEmpty)
    }

    @Test(arguments: [false, true])
    func `starter shop preserves shared rolls and discounts ordinary and guaranteed astral shelves`(allAstral: Bool) {
        var starterRNG = SeededRandomNumberGenerator(seed: 42)
        var ordinaryRNG = SeededRandomNumberGenerator(seed: 42)
        let starter = ShopOfferGenerator.generateOffers(
            stageID: ShopOfferGenerator.starterShopStageID, rewardLevel: 1, allAstral: allAstral, using: &starterRNG,
        )
        let ordinary = ShopOfferGenerator.generateOffers(
            stageID: "ordinary", rewardLevel: 1, allAstral: allAstral, using: &ordinaryRNG,
        )
        #expect(starter.count == ShopOfferGenerator.offerCount)
        #expect(ordinary.count == ShopOfferGenerator.offerCount)
        if allAstral {
            #expect(ordinary.allSatisfy { $0.item.rarity == .astral && !$0.item.isTrinket })
        } else {
            #expect(ordinary.contains { $0.item.rarity == .basic })
        }
        for (discounted, full) in zip(starter, ordinary) {
            #expect(discounted.item.templateID == full.item.templateID)
            #expect(discounted.item.affixPowers == full.item.affixPowers)
            #expect(discounted.price == full.price / 2)
            switch full.item.rarity {
            case .basic:
                #expect(ShopOfferGenerator.basePriceRange.contains(full.price))
            case .astral:
                let base = full.price / ShopOfferGenerator.astralPriceMultiplier
                #expect(ShopOfferGenerator.basePriceRange.contains(base))
                #expect(full.price == base * ShopOfferGenerator.astralPriceMultiplier)
            case .unique:
                Issue.record("Shops never offer Uniques")
            }
        }
    }

    @Test func `price discount percent reduces non starter shop prices`() throws {
        let stageID = "chapter-2-stage-8"
        var undiscountedRNG = SeededRandomNumberGenerator(seed: 7)
        let fullPriceOffers = ShopOfferGenerator.generateOffers(
            stageID: stageID,
            rewardLevel: 6,
            count: 4,
            using: &undiscountedRNG,
        )
        var discountedRNG = SeededRandomNumberGenerator(seed: 7)
        let discountedOffers = ShopOfferGenerator.generateOffers(
            stageID: stageID,
            rewardLevel: 6,
            count: 4,
            priceDiscountPercent: 10,
            using: &discountedRNG,
        )

        #expect(fullPriceOffers.count == discountedOffers.count)
        for (full, discounted) in zip(fullPriceOffers, discountedOffers) {
            try #require(full.id == discounted.id)
            let expected = max(1, (full.price * 90) / 100)
            #expect(discounted.price == expected)
        }
    }

    @Test func `shop shelf reserves unique unowned trinkets`() throws {
        let owned = try #require(GameContent.trinketItems.first).templateID
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 4)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-4-stage-8",
            rewardLevel: 20,
            count: 100,
            ownedTrinketIDs: [owned],
            using: &randomNumberGenerator,
        )
        let trinketIDs = offers.map(\.item).filter(\.isTrinket).map(\.templateID)

        try #expect(!trinketIDs.isEmpty)
        try #expect(!trinketIDs.contains(owned))
        try #expect(Set(trinketIDs).count == trinketIDs.count)
    }
}
