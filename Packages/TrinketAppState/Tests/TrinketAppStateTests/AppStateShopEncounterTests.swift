import Foundation
import Testing
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStateShopEncounterTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `shop stage opens encounter with offers`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.encounters.activeShopEncounter)
        #expect(session.stage.id == "chapter-2-stage-8")
        #expect(!session.offers.isEmpty)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-1")
    }

    @Test func `reopening shop after purchase does not burn gold on same offer`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let firstSession = try #require(state.encounters.activeShopEncounter)
        let offer = try #require(firstSession.offers.first)
        try state.playerSave.performFixtureMutation { save in
            save.roster.gold = offer.price * 3
        }

        #expect(state.encounters.purchaseShopOffer(session: firstSession, offerID: offer.id) == .committed)
        #expect(firstSession.lastPurchasedOfferID == offer.id)
        #expect(state.encounters.purchaseShopOffer(session: firstSession, offerID: offer.id) == .rejected)
        #expect(firstSession.lastPurchasedOfferID == offer.id)
        let goldAfterFirst = state.playerSave.roster.gold
        let itemsAfterFirst = state.playerSave.inventory.items.count

        state.encounters.activeShopEncounter = nil
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let secondSession = try #require(state.encounters.activeShopEncounter)
        #expect(secondSession.offers.first?.id == offer.id)

        #expect(state.encounters.purchaseShopOffer(session: secondSession, offerID: offer.id) == .rejected)
        #expect(state.playerSave.roster.gold == goldAfterFirst)
        #expect(state.playerSave.inventory.items.count == itemsAfterFirst)
    }

    @Test func `finish shop encounter completes stage without free item reward`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(stage.rewards.itemTemplateIDs.isEmpty)

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        try state.playerSave.performFixtureMutation { save in
            save.roster.gold = 0
        }
        let itemsBefore = state.playerSave.inventory.items.count

        try state.encounters.finishShopEncounter(session: #require(state.encounters.activeShopEncounter))

        #expect(state.encounters.activeShopEncounter == nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-2-stage-8"))
        #expect(state.playerSave.journey.activeStageID == "chapter-2-stage-9")
        #expect(state.playerSave.roster.gold == 0)
        #expect(state.playerSave.inventory.items.count == itemsBefore)
    }

    @Test func `mystery encounter does not open while shop is active`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.journey.handleStagePrimaryAction(for: shopStage) == nil)
        #expect(state.encounters.activeShopEncounter != nil)

        #expect(
            state.journey.beginMysteryEncounter(for: mysteryStage) == nil,
        )
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.encounters.activeShopEncounter != nil)
    }

    @Test func `replacing an encounter leaves only the current cover active`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        #expect(state.journey.handleStagePrimaryAction(for: shopStage) == nil)
        let shop = try #require(state.encounters.activeShopEncounter)

        let origin = PlayEncounterOrigin.journey(stage: mysteryStage)
        let mystery = MysteryEncounterSession(
            origin: origin,
            encounter: origin.identity(in: state.playerSave.currentSave),
            event: event,
            combatant: nil,
        )
        state.encounters.activeMysteryEncounter = mystery
        #expect(state.encounters.activeMysteryEncounter === mystery)
        #expect(state.encounters.activeShopEncounter == nil)

        state.encounters.activeShopEncounter = nil
        #expect(state.encounters.activeMysteryEncounter === mystery)
        state.encounters.activeShopEncounter = shop
        #expect(state.encounters.activeShopEncounter === shop)
        #expect(state.encounters.activeMysteryEncounter == nil)

        state.encounters.activeMysteryEncounter = nil
        #expect(state.encounters.activeShopEncounter === shop)
    }

    @Test func `start battle does not activate while shop is open`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let battleStage = GameContent.chapters[0].stages.first(where: \.encounter.isCombat)
        let resolvedBattle = try #require(battleStage)

        #expect(state.journey.handleStagePrimaryAction(for: shopStage) == nil)
        #expect(state.encounters.activeShopEncounter != nil)

        #expect(state.journey.startBattle(for: resolvedBattle) == nil)
        #expect(state.battle.activeBattle == nil)
        #expect(state.encounters.activeShopEncounter != nil)
    }

    @Test func `shop encounter completes journey origin from encounter owner`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.encounters.activeShopEncounter?.origin == .journey(stage: stage))
        #expect(try state.encounters.finishShopEncounter(session: #require(state.encounters.activeShopEncounter)))
        #expect(state.encounters.activeShopEncounter == nil)
    }

    @Test(arguments: [false, true])
    func `stale shop exit cannot advance an imported save`(inLabyrinth: Bool) throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let origin = try shopOrigin(in: state, inLabyrinth: inLabyrinth)
        #expect(state.encounters.beginShopOrAutoComplete(origin: origin) == nil)
        let session = try #require(state.encounters.activeShopEncounter)
        try state.playerSave.performFixtureMutation { $0.sessionGeneration &+= 1 }
        let imported = state.playerSave.currentSave

        #expect(!state.encounters.finishShopEncounter(session: session))

        #expect(state.encounters.activeShopEncounter === session)
        #expect(state.playerSave.currentSave == imported)
        #expect(!state.playerSave.isRetryingSaveAction)
    }

    @Test(arguments: [false, true])
    func `empty shop completes once and survives reload`(inLabyrinth: Bool) throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let origin = try shopOrigin(in: state, inLabyrinth: inLabyrinth)
        let encounter = origin.identity(in: state.playerSave.currentSave)
        let payload = try ShopStockPersistence.encode(ShopStock(offers: []), encounter: encounter)
        try state.playerSave.performFixtureMutation { save in
            ShopStockPersistence.setPayload(payload, encounter: encounter, save: &save)
        }
        let goldBefore = state.playerSave.roster.gold
        let itemsBefore = state.playerSave.inventory.items
        let stipend = encounter.labyrinthNodeID.flatMap { state.playerSave.labyrinth.node(id: $0) }
            .map(LabyrinthCompletion.nonCombatGoldStipend) ?? 0

        guard case .autoCompleted = state.encounters.beginShopEncounter(origin: origin) else {
            Issue.record("Expected an empty Shop to complete during opening")
            return
        }
        let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        #expect(!encounter.isPlayable(in: reloaded.currentSave))
        #expect(reloaded.roster.gold == goldBefore + stipend)
        #expect(reloaded.inventory.items == itemsBefore)
        let completed = reloaded.currentSave
        var replay = completed
        #expect(NonCombatEncounterCompletion.complete(encounter: encounter, save: &replay, recordReceipt: { _ in }) == .unavailable)
        #expect(replay == completed)
    }

    private func shopOrigin(in state: PlaySession, inLabyrinth: Bool) throws -> PlayEncounterOrigin {
        if inLabyrinth {
            _ = state.labyrinth.enter()
            let nodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .shop, in: state))
            return .labyrinth(nodeID: nodeID)
        }
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        return .journey(stage: stage)
    }

    #if DEBUG
    @Test func `retired shop callbacks cannot buy from or complete a replacement with the same stock`() async throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let retired = try #require(state.encounters.activeShopEncounter)
        let offer = try #require(retired.offers.first)
        let replacement = ShopEncounterSession(origin: retired.origin, encounter: retired.encounter, offers: retired.offers)
        state.encounters.activeShopEncounter = replacement
        try state.playerSave.performFixtureMutation { $0.roster.gold = offer.price * 3 }
        let before = state.playerSave.currentSave

        #expect(state.encounters.purchaseShopOffer(session: retired, offerID: offer.id) == .rejected)
        #expect(!state.encounters.finishShopEncounter(session: retired))
        #expect(state.encounters.activeShopEncounter === replacement)
        #expect(replacement.lastPurchasedOfferID == nil)
        #expect(state.playerSave.currentSave == before)
        #expect(!state.playerSave.isRetryingSaveAction)

        state.playerSave.forcesNextSaveFailure = true
        #expect(state.encounters.purchaseShopOffer(session: replacement, offerID: offer.id) == .retrying)
        #expect(state.encounters.purchaseShopOffer(session: retired, offerID: offer.id) == .rejected)
        #expect(!state.encounters.finishShopEncounter(session: retired))
        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { state.playerSave.isRetryingSaveAction }
        #expect(replacement.lastPurchasedOfferID == offer.id)
        #expect(state.playerSave.roster.gold == before.roster.gold - offer.price)
    }

    @Test func `empty shop retries without reporting completion before a durable write`() async throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let origin = try shopOrigin(in: state, inLabyrinth: false)
        let encounter = origin.identity(in: playerSave.currentSave)
        let payload = try ShopStockPersistence.encode(ShopStock(offers: []), encounter: encounter)
        try playerSave.performFixtureMutation { save in
            ShopStockPersistence.setPayload(payload, encounter: encounter, save: &save)
        }
        let before = playerSave.currentSave

        playerSave.forcesNextSaveFailure = true
        #expect(state.encounters.beginShopOrAutoComplete(origin: origin) == nil)
        #expect(playerSave.currentSave == before)
        #expect(playerSave.isRetryingSaveAction)
        #expect(state.encounters.activeShopEncounter == nil)

        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { playerSave.isRetryingSaveAction }
        let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        #expect(!encounter.isPlayable(in: reloaded.currentSave))
        #expect(reloaded.inventory.items == before.inventory.items)
    }

    @Test func `purchase reports retrying when persist fails and the silent retry completes it`() async throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeShopEncounter)
        let offer = try #require(session.offers.first)
        try playerSave.performFixtureMutation { save in
            save.roster.gold = offer.price * 3
        }
        let itemsBefore = playerSave.inventory.items.count

        playerSave.forcesNextSaveFailure = true
        #expect(state.encounters.purchaseShopOffer(session: session, offerID: offer.id) == .retrying)
        #expect(session.lastPurchasedOfferID == nil)
        // The accepted attempt's rolled-back write left the save intact.
        #expect(playerSave.roster.gold == offer.price * 3)
        #expect(playerSave.inventory.items.count == itemsBefore)

        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { playerSave.isRetryingSaveAction }
        #expect(playerSave.roster.gold == offer.price * 2)
        #expect(playerSave.inventory.items.count == itemsBefore + 1)
        #expect(session.lastPurchasedOfferID == offer.id)
    }

    @Test func `busy shop rejection cannot reuse an unrelated write failure`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.encounters.beginShopOrAutoComplete(origin: .journey(stage: stage)) == nil)
        let session = try #require(state.encounters.activeShopEncounter)
        state.playerSave.forcesNextSaveFailure = true
        #expect(!state.playerSave.persistFixtureBatch(logging: "Unrelated write fixture") { $0.roster.gold += 3 })
        #expect(state.playerSave.lastPersistenceError == .writeFailed)

        #expect(state.encounters.beginShopOrAutoComplete(origin: .journey(stage: stage)) == nil)

        #expect(!state.playerSave.isRetryingSaveAction)
        #expect(state.encounters.activeShopEncounter === session)
        #expect(state.playerSave.lastPersistenceError == .writeFailed)
    }

    @Test func `finish shop encounter retries silently when persist fails`() async throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeShopEncounter)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.finishShopEncounter(session: session))
        #expect(state.encounters.activeShopEncounter === session)
        #expect(playerSave.isRetryingSaveAction)

        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { playerSave.isRetryingSaveAction }
        #expect(state.encounters.activeShopEncounter == nil)
    }
    #endif
}
