import Foundation
import Testing
import TrinketContent
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

@MainActor
struct AppStateShopEncounterTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func shopStageOpensEncounterWithOffers() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))

        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeShopEncounter)
        #expect(session.stage.id == "chapter-1-stage-4")
        #expect(session.offers.count == ShopOfferGenerator.offerCount)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-4")
    }

    @Test func purchasingOfferSpendsGoldAndGrantsItem() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeShopEncounter)
        let offer = try #require(session.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = offer.price + 5
        }
        let goldBefore = state.roster.gold
        let itemsBefore = state.inventory.items.count

        #expect(state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == goldBefore - offer.price)
        #expect(state.inventory.items.count == itemsBefore + 1)
        #expect(state.activeShopEncounter?.purchaseCount == 1)
        #expect(state.activeShopEncounter?.lastPurchasedItemName == offer.item.displayName)
        #expect(state.activeShopEncounter?.isSoldOut(offer.id) == true)
    }

    @Test func purchaseFailsWhenGoldIsInsufficient() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeShopEncounter)
        let offer = try #require(session.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = max(0, offer.price - 1)
        }
        let goldBefore = state.roster.gold
        let itemsBefore = state.inventory.items.count

        #expect(!state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == goldBefore)
        #expect(state.inventory.items.count == itemsBefore)
        #expect(state.activeShopEncounter?.purchaseCount == 0)
        #expect(state.activeShopEncounter?.lastPurchaseError == "Not enough Gold.")
    }

    @Test func purchaseSucceedsWhenGoldEqualsPrice() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeShopEncounter)
        let offer = try #require(session.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = offer.price
        }

        #expect(state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == 0)
        #expect(state.activeShopEncounter?.isSoldOut(offer.id) == true)
    }

    @Test func sameOfferCannotBePurchasedTwiceInOneVisit() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeShopEncounter)
        let offer = try #require(session.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = offer.price * 3
        }
        let goldAfterFirstBuy = offer.price * 2

        #expect(state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == goldAfterFirstBuy)
        #expect(!state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == goldAfterFirstBuy)
        #expect(state.inventory.items.count == 1)
        #expect(state.activeShopEncounter?.lastPurchaseError == "That item is already sold.")
    }

    @Test func reopeningShopAfterPurchaseDoesNotBurnGoldOnSameOffer() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let firstSession = try #require(state.activeShopEncounter)
        let offer = try #require(firstSession.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = offer.price * 3
        }

        #expect(state.purchaseActiveShopOffer(offerID: offer.id))
        let goldAfterFirst = state.roster.gold
        let itemsAfterFirst = state.inventory.items.count
        let firstVisitToken = firstSession.visitToken

        state.dismissActiveShopEncounterWithoutCompleting()
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let secondSession = try #require(state.activeShopEncounter)
        #expect(secondSession.visitToken != firstVisitToken)
        #expect(secondSession.offers.first?.id == offer.id)

        #expect(state.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.roster.gold == goldAfterFirst - offer.price)
        #expect(state.inventory.items.count == itemsAfterFirst + 1)
        let ownedIDs = Set(state.inventory.items.map(\.id))
        #expect(ownedIDs.count == itemsAfterFirst + 1)
    }

    @Test func finishShopEncounterCompletesStageWithoutFreeItemReward() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(stage.rewards.itemTemplateIDs.isEmpty)

        #expect(state.handleStagePrimaryAction(for: stage) == nil)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = 0
        }
        let itemsBefore = state.inventory.items.count

        state.finishActiveShopEncounter()

        #expect(state.activeShopEncounter == nil)
        #expect(state.journey.current.completedStageIDs.contains("chapter-1-stage-4"))
        #expect(state.journey.current.activeStageID == "chapter-1-stage-5")
        #expect(state.roster.gold == stage.rewards.gold)
        #expect(state.inventory.items.count == itemsBefore)
    }

    @Test func dismissShopEncounterDoesNotCompleteStage() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))

        _ = state.handleStagePrimaryAction(for: stage)
        #expect(state.activeShopEncounter != nil)

        state.dismissActiveShopEncounterWithoutCompleting()

        #expect(state.activeShopEncounter == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-4")
        #expect(!state.journey.current.completedStageIDs.contains("chapter-1-stage-4"))
    }

    @Test func mysteryEncounterDoesNotOpenWhileShopIsActive() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let shopStage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.handleStagePrimaryAction(for: shopStage) == nil)
        #expect(state.activeShopEncounter != nil)

        #expect(state.beginMysteryEncounter(for: mysteryStage) == nil)
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.activeShopEncounter != nil)
    }
}
