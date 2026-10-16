import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

#if DEBUG
@MainActor
struct LabyrinthEntryRetryTests {
    @Test func `failed Labyrinth entry silently retries and survives reload`() async throws {
        let context = try AppTestContext()
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let play = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let before = playerSave.labyrinth

        playerSave.forcesNextSaveFailure = true
        #expect(play.labyrinth.enter() != nil)
        #expect(playerSave.labyrinth == before)
        #expect(!playerSave.labyrinth.hasMap)
        #expect(playerSave.isRetryingSaveAction)

        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { playerSave.isRetryingSaveAction }
        #expect(playerSave.labyrinth.hasMap)
        #expect(!playerSave.labyrinth.reachableNodeIDs().isEmpty)
        let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        #expect(reloaded.labyrinth == playerSave.labyrinth)
    }

    @Test func `pending Labyrinth entry cannot write during a new battle`() async throws {
        let context = try AppTestContext()
        let play = try context.makePlaySession()
        let playerSave = play.playerSave
        playerSave.forcesNextSaveFailure = true
        #expect(play.labyrinth.enter() != nil)
        #expect(playerSave.isRetryingSaveAction)
        let before = playerSave.labyrinth

        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        #expect(play.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(play.battle.activeBattle != nil)

        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { playerSave.isRetryingSaveAction }
        #expect(playerSave.labyrinth == before)
    }
}
#endif
