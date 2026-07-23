import Testing
import TrinketContent
import TrinketCore

struct ShopOfferGeneratorTests {
    @Test func pricesFollowBasicAndAstralRules() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            count: 40,
            using: &randomNumberGenerator
        )

        for offer in offers {
            switch offer.item.rarity {
            case .basic:
                #expect(ShopOfferGenerator.basePriceRange.contains(offer.price))
            case .astral:
                let base = offer.price / ShopOfferGenerator.astralPriceMultiplier
                #expect(ShopOfferGenerator.basePriceRange.contains(base))
                #expect(offer.price == base * ShopOfferGenerator.astralPriceMultiplier)
            }
        }
    }

    @Test func rarityMixIsMostlyBasicAcrossManyRolls() {
        var basicCount = 0
        var astralCount = 0
        for seed in UInt64(1) ... 200 {
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let offers = ShopOfferGenerator.generateOffers(
                stageID: "shop-rarity",
                count: 1,
                using: &randomNumberGenerator
            )
            switch offers.first?.item.rarity {
            case .basic:
                basicCount += 1
            case .astral:
                astralCount += 1
            case nil:
                Issue.record("Expected an offer")
            }
        }

        #expect(basicCount > astralCount)
        #expect(astralCount > 0)
        #expect(basicCount + astralCount == 200)
    }

    @Test func sameSeedProducesIdenticalOffers() {
        var first = SeededRandomNumberGenerator(seed: ShopOfferGenerator.seed(forStageID: "chapter-2-stage-8"))
        var second = SeededRandomNumberGenerator(seed: ShopOfferGenerator.seed(forStageID: "chapter-2-stage-8"))

        let firstOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &first)
        let secondOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-2-stage-8", using: &second)

        #expect(firstOffers == secondOffers)
    }

    @Test func emptyBaseTypesYieldNoOffers() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "empty",
            baseTypes: [],
            using: &randomNumberGenerator
        )
        #expect(offers.isEmpty)
    }

    @Test func offerIDsAreUniqueWithinAShelf() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            using: &randomNumberGenerator
        )
        let ids = offers.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func shopOfferItemsResolveArtByTemplateID() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-2-stage-8",
            using: &randomNumberGenerator
        )

        for offer in offers {
            #expect(
                offer.item.id != offer.item.templateID,
                "Shop offers use instance ids distinct from template ids"
            )
            #expect(
                offer.item.artReference != nil,
                "Missing art for shop offer template \(offer.item.templateID)"
            )
        }
    }

    @Test func chapter1ShopOffersHaveAllBasicExceptOneAstral() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-1-stage-8",
            count: 4,
            using: &randomNumberGenerator
        )

        let basicOffers = offers.filter { $0.item.rarity == .basic }
        let astralOffers = offers.filter { $0.item.rarity == .astral }

        #expect(offers.count == 4)
        #expect(basicOffers.count == 3)
        #expect(astralOffers.count == 1)
    }
}
