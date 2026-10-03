import Testing
import TrinketContent
import TrinketCore

struct ShopOfferGeneratorTests {
    @Test func `prices follow basic and astral rules`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            rewardLevel: 6,
            count: 40,
            using: &randomNumberGenerator,
        )

        for offer in offers {
            switch offer.item.rarity {
            case .basic:
                #expect(ShopOfferGenerator.basePriceRange.contains(offer.price))
            case .astral:
                let base = offer.price / ShopOfferGenerator.astralPriceMultiplier
                #expect(ShopOfferGenerator.basePriceRange.contains(base))
                #expect(offer.price == base * ShopOfferGenerator.astralPriceMultiplier)
            case .unique:
                Issue.record("Shops never offer Uniques")
            }
        }
    }

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

    @Test func `shop offer items resolve art by template ID`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            rewardLevel: 6,
            using: &randomNumberGenerator,
        )

        for offer in offers {
            #expect(
                offer.item.isTrinket || offer.item.id != offer.item.templateID,
                "Shop offers use instance ids distinct from template ids",
            )
            #expect(
                offer.item.artReference != nil,
                "Missing art for shop offer template \(offer.item.templateID)",
            )
        }
    }

    @Test func `starter shop uses shared odds and discounts premium offers`() {
        var starterRNG = SeededRandomNumberGenerator(seed: 42)
        var ordinaryRNG = SeededRandomNumberGenerator(seed: 42)
        let starter = ShopOfferGenerator.generateOffers(
            stageID: ShopOfferGenerator.starterShopStageID, rewardLevel: 1, count: 200, using: &starterRNG,
        )
        let ordinary = ShopOfferGenerator.generateOffers(
            stageID: "ordinary", rewardLevel: 1, count: 200, using: &ordinaryRNG,
        )
        #expect(starter.contains { $0.item.rarity == .astral })
        for (discounted, full) in zip(starter, ordinary) {
            #expect(discounted.item.templateID == full.item.templateID)
            #expect(discounted.item.affixPowers == full.item.affixPowers)
            #expect(discounted.price == full.price / 2)
        }
    }

    @Test func `guaranteed astral shop effect constrains the shared pool`() {
        var rng = SeededRandomNumberGenerator(seed: 7)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "labyrinth", rewardLevel: 1, allAstral: true, using: &rng,
        )
        #expect(offers.count == ShopOfferGenerator.offerCount)
        #expect(offers.allSatisfy { $0.item.rarity == .astral && !$0.item.isTrinket })
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
