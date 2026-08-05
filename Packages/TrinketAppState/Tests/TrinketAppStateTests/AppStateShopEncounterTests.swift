import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
struct AppStateShopEncounterTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func shopStageOpensEncounterWithOffers() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.encounters.activeShopEncounter)
        #expect(session.stage.id == "chapter-2-stage-8")
        #expect(!session.offers.isEmpty)
        // Opening a shop does not advance journey progress.
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-1")
    }

    @Test func reopeningShopAfterPurchaseDoesNotBurnGoldOnSameOffer() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let firstSession = try #require(state.encounters.activeShopEncounter)
        let offer = try #require(firstSession.offers.first)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = offer.price * 3
        }

        #expect(state.encounters.purchaseActiveShopOffer(offerID: offer.id))
        let goldAfterFirst = state.playerSave.roster.gold
        let itemsAfterFirst = state.playerSave.inventory.items.count
        let firstVisitToken = firstSession.visitToken

        state.encounters.dismissActiveShopEncounterWithoutCompleting()
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let secondSession = try #require(state.encounters.activeShopEncounter)
        #expect(secondSession.visitToken != firstVisitToken)
        #expect(secondSession.offers.first?.id == offer.id)

        #expect(state.encounters.purchaseActiveShopOffer(offerID: offer.id))
        #expect(state.playerSave.roster.gold == goldAfterFirst - offer.price)
        #expect(state.playerSave.inventory.items.count == itemsAfterFirst + 1)
        let ownedIDs = Set(state.playerSave.inventory.items.map(\.id))
        #expect(ownedIDs.count == itemsAfterFirst + 1)
    }

    @Test func finishShopEncounterCompletesStageWithoutFreeItemReward() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(stage.rewards.itemTemplateIDs.isEmpty)

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        try state.playerSave.performBatchMutation { save in
            save.roster.gold = 0
        }
        let itemsBefore = state.playerSave.inventory.items.count

        state.encounters.finishActiveShopEncounter()

        #expect(state.encounters.activeShopEncounter == nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-2-stage-8"))
        #expect(state.playerSave.journey.activeStageID == "chapter-2-stage-9")
        #expect(state.playerSave.roster.gold == 0)
        #expect(state.playerSave.inventory.items.count == itemsBefore)
    }

    @Test func dismissShopEncounterDoesNotCompleteStage() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        _ = state.journey.handleStagePrimaryAction(for: stage)
        #expect(state.encounters.activeShopEncounter != nil)

        state.encounters.dismissActiveShopEncounterWithoutCompleting()

        #expect(state.encounters.activeShopEncounter == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-1")
        #expect(!state.playerSave.journey.completedStageIDs.contains("chapter-2-stage-8"))
    }

    @Test func mysteryEncounterDoesNotOpenWhileShopIsActive() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.journey.handleStagePrimaryAction(for: shopStage) == nil)
        #expect(state.encounters.activeShopEncounter != nil)

        #expect(
            state.journey.beginMysteryEncounter(for: mysteryStage) == nil
        )
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.encounters.activeShopEncounter != nil)
    }

    #if DEBUG
    @Test func finishShopEncounterSurfacesLeaveFailureWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeShopEncounter)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter != nil)
        #expect(session.leaveFailureMessage != nil)

        #expect(state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter == nil)
    }
    #endif
}
