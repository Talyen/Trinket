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
}
