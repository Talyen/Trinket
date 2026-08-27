import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketPersistenceTestSupport

struct ShopPurchaseApplierTests {
    @Test func purchaseSpendsGoldAndGrantsItem() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 100)
        let offer = try makeOffer(price: 28)
        let initialItemCount = save.inventory.items.count
        let visitToken = "visit-a"

        let result = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-8",
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
                stageID: "chapter-2-stage-8",
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
            stageID: "chapter-2-stage-8",
            save: &save
        )

        #expect(result == .insufficientGold)
        #expect(save.roster.gold == 10)
        #expect(save.inventory.items == initialItems)
    }

    @Test func purchaseFailsWhenOfferPriceIsNegative() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 50)
        let offer = try makeOffer(price: -20)

        let result = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: "visit-a",
            stageID: "chapter-2-stage-8",
            save: &save
        )

        #expect(result == .insufficientGold)
        #expect(save.roster.gold == 50)
    }

    @Test func repeatedPurchaseOfSameOfferInSameVisitIsAlreadyOwned() throws {
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let offer = try makeOffer(price: 20)
        let visitToken = "visit-a"

        let first = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-8",
            save: &save
        )
        let second = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: visitToken,
            stageID: "chapter-2-stage-8",
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
            stageID: "chapter-2-stage-8",
            save: &save
        )
        let second = ShopPurchaseApplier.purchase(
            offer: offer,
            visitToken: "visit-b",
            stageID: "chapter-2-stage-8",
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

    @Test func trinketCannotBePurchasedMoreThanOnce() throws {
        let trinket = try #require(GameContent.trinketItems.first)
        var save = SaveTestSupport.makeSave(modifiedAt: .now, gold: 200)
        let firstOffer = ShopOffer(id: "trinket-offer-a", item: trinket, price: 20)
        let secondOffer = ShopOffer(id: "trinket-offer-b", item: trinket, price: 20)

        let first = ShopPurchaseApplier.purchase(
            offer: firstOffer,
            visitToken: "visit-a",
            stageID: "chapter-2-stage-8",
            save: &save
        )
        let second = ShopPurchaseApplier.purchase(
            offer: secondOffer,
            visitToken: "visit-b",
            stageID: "chapter-2-stage-8",
            save: &save
        )

        guard case let .success(purchased) = first else {
            Issue.record("Expected first Trinket purchase to succeed")
            return
        }
        #expect(purchased == trinket)
        #expect(second == .alreadyOwned)
        #expect(save.roster.gold == 180)
        #expect(save.inventory.items == [trinket])
    }

    @Test @MainActor func campaignAppliersSurviveStoreReload() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let stage = GameContent.chapters[0].stages[0]
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        let loot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: GameContent.chapters[0]),
            enemyIsBoss: false,
            worldSeed: store.currentSave.worldSeed,
            ownedUniqueIDs: []
        )
        let offer = try makeOffer(price: 28)
        var rng = SeededRandomNumberGenerator(seed: 1)
        try store.performBatchMutation { save in
            save.roster.gold = 100
            save.homestead.resources = [:]
            StageCompletion.complete(
                stage,
                hero: hero,
                companion: companion,
                loot: loot,
                in: GameContent.chapters,
                save: &save
            )
            _ = ShopPurchaseApplier.purchase(
                offer: offer,
                visitToken: "visit-reload",
                stageID: "chapter-2-stage-8",
                save: &save
            )
            _ = MysteryEffectApplier.apply(
                [.gainMaterial(.herbs)],
                stageID: "chapter-1-stage-2",
                choiceID: "harvest",
                encounterLevel: 1,
                save: &save,
                using: &rng
            )
        }
        let gold = store.roster.gold
        let herbs = store.homestead.resources[.herbs]
        let items = store.inventory.items.count
        let reloaded = try PlayerSaveStore(storeURL: context.storeURL(), disableCloudSync: true)
        #expect(reloaded.journey.hasClaimedRewards(for: stage))
        #expect(reloaded.roster.gold == gold)
        #expect(reloaded.homestead.resources[.herbs] == herbs)
        #expect((herbs ?? 0) > 0)
        #expect(reloaded.inventory.items.count == items)
        #expect(reloaded.inventory.item(matching: loot.item.id) != nil)
    }

    private func makeOffer(price: Int) throws -> ShopOffer {
        let item = try SaveTestSupport.makeGeneratedItem(
            baseID: "longsword",
            rarity: .basic,
            id: "chapter-2-stage-8-offer-0",
            templateID: "longsword-basic",
            seed: 7
        )
        return ShopOffer(id: "chapter-2-stage-8-offer-0", item: item, price: price)
    }
}
