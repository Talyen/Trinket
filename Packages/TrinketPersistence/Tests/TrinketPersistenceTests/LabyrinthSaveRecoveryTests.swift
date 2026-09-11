import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Suite("LabyrinthSaveRecovery")
struct LabyrinthSaveRecoveryTests {
    @Test func `enter rebuilds unreadable map`() {
        var save = PlayerSave.fresh
        let expectedSeed = save.worldSeed
        save.labyrinth = PlayerLabyrinthState(
            worldSeed: 55,
            hasEntered: true,
            isMapPayloadUnreadable: true,
        )

        LabyrinthCompletion.enter(save: &save)

        #expect(save.labyrinth.hasMap)
        #expect(!save.labyrinth.isMapPayloadUnreadable)
        #expect(save.labyrinth.worldSeed == expectedSeed)
        #expect(!save.labyrinth.nodes.isEmpty)
    }

    @Test @MainActor func `store reload heals corrupt map blob`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let corruptBlob = Data("{not-valid-labyrinth-json".utf8)

        do {
            let store = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
            )
            #expect(store.persistBatch(logging: "Test setup") { $0.labyrinth = PlayerLabyrinthState(worldSeed: 55, hasEntered: true) })
        }

        do {
            let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
            let model = try #require(sideContext.fetch(FetchDescriptor<LabyrinthProgressModel>()).first)
            model.worldSeed = 55
            model.hasEntered = true
            model.mapPayload = corruptBlob
            try sideContext.save()
        }

        let loaded = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
        )
        #expect(!loaded.labyrinth.isMapPayloadUnreadable)
        #expect(loaded.labyrinth.hasMap)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(!reloaded.labyrinth.isMapPayloadUnreadable)
        #expect(reloaded.labyrinth.hasMap)
    }
}
