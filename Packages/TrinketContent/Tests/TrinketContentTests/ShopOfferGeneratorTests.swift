import Testing
import TrinketContent
import TrinketCore

struct ShopOfferGeneratorTests {
    @Test func `prices follow basic and astral rules`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
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

    @Test func `rarity mix is mostly basic across many rolls`() {
        var basicCount = 0
        var astralCount = 0
        for seed in UInt64(1) ... 24 {
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let offers = ShopOfferGenerator.generateOffers(
                stageID: "shop-rarity",
                count: 1,
                using: &randomNumberGenerator,
            )
            switch offers.first?.item.rarity {
            case .basic:
                basicCount += 1
            case .astral:
                astralCount += 1
            case .unique:
                Issue.record("Shops never offer Uniques")
            case nil:
                Issue.record("Expected an offer")
            }
        }

        #expect(basicCount > astralCount)
        #expect(astralCount > 0)
        #expect(basicCount + astralCount == 24)
    }

    @Test func `same seed produces identical offers`() {
        var first = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 7, forStageID: "chapter-2-stage-8"),
        )
        var second = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 7, forStageID: "chapter-2-stage-8"),
        )

        let firstOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &first)
        let secondOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &second)

        #expect(firstOffers == secondOffers)
    }

    @Test func `different world seeds produce different shelves`() {
        var first = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 7, forStageID: "chapter-2-stage-8"),
        )
        var second = SeededRandomNumberGenerator(
            seed: ShopOfferGenerator.seed(worldSeed: 9, forStageID: "chapter-2-stage-8"),
        )
        let firstOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &first)
        let secondOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &second)
        #expect(firstOffers != secondOffers)
    }

    @Test func `empty base types yield no offers`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "empty",
            baseTypes: [],
            using: &randomNumberGenerator,
        )
        #expect(offers.isEmpty)
    }

    @Test func `offer I ds are unique within A shelf`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            using: &randomNumberGenerator,
        )
        let ids = offers.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func `shop offer items resolve art by template ID`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            using: &randomNumberGenerator,
        )

        for offer in offers {
            #expect(
                offer.item.id != offer.item.templateID,
                "Shop offers use instance ids distinct from template ids",
            )
            #expect(
                offer.item.artReference != nil,
                "Missing art for shop offer template \(offer.item.templateID)",
            )
        }
    }

    @Test func `starter shop offers are all basic at half price`() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: ShopOfferGenerator.starterShopStageID,
            count: 4,
            using: &randomNumberGenerator,
        )

        let discountedMin = max(
            1,
            (ShopOfferGenerator.basePriceRange.lowerBound * ShopOfferGenerator.starterShopPriceDiscountPercent) / 100,
        )
        let discountedMax =
            (ShopOfferGenerator.basePriceRange.upperBound * ShopOfferGenerator.starterShopPriceDiscountPercent) / 100
        #expect(offers.count == 4)
        for offer in offers {
            #expect(offer.item.rarity == .basic)
            #expect((discountedMin ... discountedMax).contains(offer.price))
        }
    }

    @Test func `price discount percent reduces non starter shop prices`() throws {
        let stageID = "chapter-2-stage-8"
        var undiscountedRNG = SeededRandomNumberGenerator(seed: 7)
        let fullPriceOffers = ShopOfferGenerator.generateOffers(
            stageID: stageID,
            count: 4,
            using: &undiscountedRNG,
        )
        var discountedRNG = SeededRandomNumberGenerator(seed: 7)
        let discountedOffers = ShopOfferGenerator.generateOffers(
            stageID: stageID,
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
            count: 100,
            ownedTrinketIDs: [owned],
            using: &randomNumberGenerator,
        )
        let trinketIDs = offers.map(\.item).filter(\.isTrinket).map(\.templateID)

        try #expect(!trinketIDs.contains(owned))
        try #expect(Set(trinketIDs).count == trinketIDs.count)
    }
}
