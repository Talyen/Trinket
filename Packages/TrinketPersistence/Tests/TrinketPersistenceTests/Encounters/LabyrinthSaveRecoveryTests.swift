import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Suite("LabyrinthSaveRecovery")
struct LabyrinthSaveRecoveryTests {
    @Test(arguments: [LabyrinthNodeType.battle, .boss], ["missing", "unknown", "wrongType", "valid"])
    @MainActor func `readable saved combat nodes retain playable enemy assignments`(
        type: LabyrinthNodeType, savedEnemy: String,
    ) throws {
        var save = PlayerSave.testSeed
        save.labyrinth.ensureMap(seed: 55)
        save = PlayerSaveSanitizer.sanitize(save)
        let original = try #require(save.labyrinth.nodes.values.sorted { $0.id < $1.id }.first { $0.type == type })
        let wrongType = try #require(GameContent.enemies.first { $0.isBoss != (type == .boss) })
        let enemyID: String? = switch savedEnemy {
        case "missing": nil
        case "unknown": "missing-saved-enemy"
        case "wrongType": wrongType.id
        default: original.enemyID
        }
        save.labyrinth.nodes[original.id] = LabyrinthNode(
            id: original.id, type: original.type, enemyID: enemyID,
            depth: original.depth, clusterID: original.clusterID, gridPosition: original.gridPosition,
            modifierIDs: original.modifierIDs, recruitEventID: original.recruitEventID,
            mysteryEventID: original.mysteryEventID, mysteryOffersPayload: original.mysteryOffersPayload,
            shopPayload: original.shopPayload, outgoingIDs: original.outgoingIDs,
            isCleared: original.isCleared, isRevealed: original.isRevealed,
        )
        let expected = PlayerSaveSanitizer.sanitize(save).labyrinth
        let context = try PersistenceTestContext()
        let loaded = try context.seedAndReload(save)
        let repaired = try #require(loaded.labyrinth.node(id: original.id))
        let enemy = try #require(repaired.enemyID.flatMap { GameContent.enemy(matching: $0) })

        #expect(enemy.isBoss == (type == .boss))
        if savedEnemy == "valid" {
            #expect(repaired.enemyID == original.enemyID)
        }
        #expect(loaded.labyrinth == expected)
        #expect(repaired.outgoingIDs == original.outgoingIDs)
        #expect(repaired.isCleared == original.isCleared)
        #expect(repaired.mysteryEventID == original.mysteryEventID)
        #expect(repaired.mysteryOffersPayload == original.mysteryOffersPayload)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.labyrinth == expected)
    }

    @Test @MainActor func `negative saved boss depth repairs its exit without losing cleared progress`() throws {
        var save = PlayerSave.testSeed
        save.labyrinth.ensureMap(seed: 55)
        let boss = try #require(save.labyrinth.nodes.values.first { $0.type == .boss })
        save.labyrinth.nodes[boss.id] = LabyrinthNode(
            id: boss.id, type: .boss, enemyID: boss.enemyID,
            depth: -4, clusterID: boss.clusterID, gridPosition: boss.gridPosition,
            modifierIDs: boss.modifierIDs, isCleared: true, isRevealed: true,
        )
        let context = try PersistenceTestContext()
        let loaded = try context.seedAndReload(save)
        let repaired = try #require(loaded.labyrinth.node(id: boss.id))
        let exit = try #require(repaired.outgoingIDs.first)
        #expect(repaired.depth == 0)
        #expect(repaired.isCleared)
        #expect(loaded.labyrinth.isNodeReachable(exit))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.labyrinth == loaded.labyrinth)
    }

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
            let store = try context.makeSaveStore()
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

        let loaded = try context.makeReloadedStore()
        #expect(!loaded.labyrinth.isMapPayloadUnreadable)
        #expect(loaded.labyrinth.hasMap)

        let reloaded = try context.makeReloadedStore()
        #expect(!reloaded.labyrinth.isMapPayloadUnreadable)
        #expect(reloaded.labyrinth.hasMap)
    }
}
