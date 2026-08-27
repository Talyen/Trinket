import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Suite("LabyrinthSaveRecovery")
struct LabyrinthSaveRecoveryTests {
    @Test func enterDoesNotRebuildUnreadableMap() {
        var save = PlayerSave.fresh
        save.labyrinth = PlayerLabyrinthState(
            worldSeed: 55,
            hasEntered: true,
            isMapPayloadUnreadable: true
        )

        LabyrinthCompletion.enter(save: &save)

        // Phase 2.2 auto-recovery: unreadable + hasEntered now rebuilds
        // instead of looping "Labyrinth Error" forever. Seed follows
        // PlayerSave.worldSeed (canonical) so labyrinth.worldSeed may change
        // from the manually set 55 to the save's worldSeed.
        #expect(save.labyrinth.hasMap)
        #expect(!save.labyrinth.isMapPayloadUnreadable)
        #expect(save.labyrinth.worldSeed != 0)
        #expect(!save.labyrinth.nodes.isEmpty)
    }

    @Test @MainActor func storeReloadThenEnterPreservesCorruptMapBlob() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "labyrinth-corrupt-enter")
        defer { SaveTestSupport.removeTempDirectory(directory) }
        let storeURL = SaveTestSupport.makeStoreURL(directoryURL: directory)
        let corruptBlob = Data("{not-valid-labyrinth-json".utf8)

        do {
            let store = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
                persistSaveImmediately: true
            )
            store.labyrinth = PlayerLabyrinthState(worldSeed: 55, hasEntered: true)
        }

        do {
            let context = try SaveTestSupport.makeSideContext(storeURL: storeURL)
            let model = try #require(context.fetch(FetchDescriptor<LabyrinthProgressModel>()).first)
            model.worldSeed = 55
            model.hasEntered = true
            model.mapPayload = corruptBlob
            try context.save()
        }

        let loaded = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
        )
        #expect(loaded.labyrinth.isMapPayloadUnreadable)
        #expect(!loaded.labyrinth.hasMap)

        #expect(loaded.persistBatch(logging: "enter") { save in
            LabyrinthCompletion.enter(save: &save)
        })
        // Auto-recovery on enter now rebuilds instead of preserving corrupt blob.
        #expect(!loaded.labyrinth.isMapPayloadUnreadable)
        #expect(loaded.labyrinth.hasMap)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(!reloaded.labyrinth.isMapPayloadUnreadable)
        #expect(reloaded.labyrinth.hasMap)
        #expect(reloaded.labyrinth.worldSeed != 0)
    }

    @Test @MainActor func labyrinthSetterMigratesLegacyMapWithRosterRecruitEligibility() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "labyrinth-setter-recruits")
        defer { SaveTestSupport.removeTempDirectory(directory) }
        let store = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        let recruitIDs = store.roster.eligibleRecruitEventIDs
        try #require(!recruitIDs.isEmpty)

        let generated = LabyrinthGenerator.makeMap(
            seed: 9,
            floorCount: 1,
            eligibleRecruitEventIDs: recruitIDs
        )
        let legacy = PlayerLabyrinthState(
            worldSeed: 9,
            mapVersion: 2,
            hasEntered: true,
            clusters: generated.clusters,
            nodes: generated.nodes
        )
        try #require(legacy.nodes.values.contains { $0.type == .recruit || $0.recruitEventID != nil })

        store.labyrinth = legacy

        #expect(store.labyrinth.mapVersion == LabyrinthGenerator.currentMapVersion)
        #expect(store.labyrinth.nodes.values.contains { $0.type == .recruit || $0.recruitEventID != nil })
    }
}
