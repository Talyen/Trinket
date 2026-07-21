import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport

struct ShopPurchaseApplierTests {
    @Test func purchaseSpendsGoldAndGrantsItem() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 100)
        let offer = try makeOffer(price: 28)
        let initialItemCount = save.inventory.items.count
        let visitToken = "visit-a"

        let result = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-5",
            save: &save
        )

        guard case let .success(item) = result else {
            Issue.record("Expected successful purchase")
            return
        }
        #expect(save.roster.gold == 72)
        #expect(save.inventory.items.count == initialItemCount + 1)
        #expect(item.displayName == offer.item.displayName)
        #expect(
            item.id == ShopPurchaseApplier.inventoryInstanceID(
                stageID: "chapter-2-stage-5",
                offerID: offer.id,
                visitToken: visitToken
            )
        )
    }

    @Test func purchaseFailsWithoutSpendingWhenGoldIsInsufficient() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 10)
        let offer = try makeOffer(price: 28)
        let initialItems = save.inventory.items

        let result = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: "visit-a",
            stageID: "chapter-2-stage-5",
            save: &save
        )

        #expect(result == .insufficientGold)
        #expect(save.roster.gold == 10)
        #expect(save.inventory.items == initialItems)
    }

    @Test func repeatedPurchaseOfSameOfferInSameVisitIsAlreadyOwned() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let offer = try makeOffer(price: 20)
        let visitToken = "visit-a"

        let first = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-5",
            save: &save
        )
        let second = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-5",
            save: &save
        )

        guard case .success = first else {
            Issue.record("Expected first purchase to succeed")
            return
        }
        #expect(second == .alreadyOwned)
        #expect(save.roster.gold == 180)
        #expect(save.inventory.items.count == 1)
    }

    @Test func differentVisitTokensMintDistinctInstanceIDs() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let offer = try makeOffer(price: 20)

        let first = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: "visit-a",
            stageID: "chapter-2-stage-5",
            save: &save
        )
        let second = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: "visit-b",
            stageID: "chapter-2-stage-5",
            save: &save
        )

        guard case let .success(firstItem) = first,
              case let .success(secondItem) = second
        else {
            Issue.record("Expected two successful purchases across visits")
            return
        }
        #expect(firstItem.id != secondItem.id)
        #expect(save.roster.gold == 160)
        #expect(save.inventory.items.count == 2)
    }

    private func makeOffer(price: Int) throws -> ShopOffer {
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let item = ItemGenerator().generate(
            id: "chapter-2-stage-5-offer-0",
            templateID: "longsword-basic",
            baseType: baseType,
            rarity: .basic,
            using: &randomNumberGenerator
        )
        return ShopOffer(id: "chapter-2-stage-5-offer-0", item: item, price: price)
    }
}
