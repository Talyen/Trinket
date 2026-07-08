import Testing
import TrinketContent
import TrinketCore

struct ShopOfferGeneratorTests {
    @Test func generatesRequestedOfferCount() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-1-stage-4",
            using: &randomNumberGenerator
        )

        #expect(offers.count == ShopOfferGenerator.offerCount)
    }

    @Test func pricesFollowBasicAndAstralRules() {
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let offers = ShopOfferGenerator.generateOffers(
            stageID: "chapter-1-stage-4",
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
        var first = SeededRandomNumberGenerator(seed: ShopOfferGenerator.seed(forStageID: "chapter-1-stage-4"))
        var second = SeededRandomNumberGenerator(seed: ShopOfferGenerator.seed(forStageID: "chapter-1-stage-4"))

        let firstOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-1-stage-4", using: &first)
        let secondOffers = ShopOfferGenerator.generateOffers(stageID: "chapter-1-stage-4", using: &second)

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
}
