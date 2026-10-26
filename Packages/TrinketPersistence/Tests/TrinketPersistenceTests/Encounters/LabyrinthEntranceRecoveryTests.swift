import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct LabyrinthEntranceRecoveryTests {
    enum Damage: CaseIterable {
        case missing, missingWithCluster, uncleared, emptyExit, danglingExit
    }

    @Test(arguments: Damage.allCases) @MainActor
    func `damaged entrance recovers the retained first floor and survives reload`(damage: Damage) throws {
        var save = PlayerSave.fresh
        save.worldSeed = 21
        save.labyrinth.ensureMap(seed: save.worldSeed)
        let entryID = try #require(save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs.first)
        let mysteryID = try #require(save.labyrinth.nodes.values.first { $0.type == .mystery }?.id)
        save.labyrinth.nodes[mysteryID]?.mysteryEventID = "hidden-cache"
        save.labyrinth.nodes[mysteryID]?.mysteryOffersPayload = Data("retained-offer".utf8)
        let retainedRooms = save.labyrinth.nodes.filter { $0.value.depth == 1 }
        switch damage {
        case .missing:
            save.labyrinth.nodes.removeValue(forKey: LabyrinthGenerator.entranceNodeID)
        case .missingWithCluster:
            save.labyrinth.nodes.removeValue(forKey: LabyrinthGenerator.entranceNodeID)
            save.labyrinth.clusters.removeAll { $0.id == LabyrinthGenerator.entranceClusterID }
        case .uncleared:
            save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.isCleared = false
            save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.isRevealed = false
        case .emptyExit:
            save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs = []
        case .danglingExit:
            save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs = ["missing-room"]
        }
        #expect(save.labyrinth.hasMap)
        #expect(save.labyrinth.reachableNodeIDs().isEmpty)

        let repaired = LabyrinthSanitizer.sanitize(save.labyrinth)
        #expect(repaired.isNodeReachable(entryID))
        #expect(repaired.nodes.filter { $0.value.depth == 1 } == retainedRooms)
        #expect(repaired.nodes[LabyrinthGenerator.entranceNodeID]?.isCleared == true)
        #expect(repaired.nodes[LabyrinthGenerator.entranceNodeID]?.isRevealed == true)
        #expect(repaired.cluster(id: LabyrinthGenerator.entranceClusterID)?.nodeIDs == [LabyrinthGenerator.entranceNodeID])
        #expect(LabyrinthSanitizer.sanitize(repaired) == repaired)
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(save)
        #expect(reloaded.labyrinth == repaired)
        #expect(try context.makeReloadedStore().labyrinth == repaired)
    }

    @Test func `entrance repair preserves existing exits and cleared floor progress`() throws {
        var map = PlayerLabyrinthState.freshStart
        map.ensureMap(seed: 21)
        let entryID = try #require(map.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs.first)
        map.markCleared(nodeID: entryID)
        let extraID = try #require(map.nodes.values.first { $0.depth == 1 && $0.id != entryID }?.id)
        map.nodes[LabyrinthGenerator.entranceNodeID]?.outgoingIDs.append(extraID)
        #expect(LabyrinthSanitizer.sanitize(map) == map)
    }

    @Test(arguments: [false, true])
    func `entrance repair does not reinterpret future or unentered maps`(futureVersion: Bool) {
        var map = PlayerLabyrinthState.freshStart
        map.ensureMap(seed: 21)
        map.nodes.removeValue(forKey: LabyrinthGenerator.entranceNodeID)
        if futureVersion {
            map.mapVersion += 1
        } else {
            map.hasEntered = false
        }
        #expect(LabyrinthSanitizer.sanitize(map).nodes[LabyrinthGenerator.entranceNodeID] == nil)
    }
}
