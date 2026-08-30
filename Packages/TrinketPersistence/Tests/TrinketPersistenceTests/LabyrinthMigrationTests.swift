import Testing
import TrinketContent
@testable import TrinketPersistence

struct LabyrinthMigrationTests {
    @Test func `preserves current floor progress across version four node I ds`() throws {
        let legacy = try makeVersionFourState(seed: 9, clearedNodeCount: 2)

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(legacy)
        let migratedFloor = try #require(sanitized.clusters.first { $0.depthBand == 1 })

        #expect(migratedFloor.id == "labyrinth-cluster-1")
        #expect(migratedFloor.nodeIDs.count(where: { sanitized.nodes[$0]?.isCleared == true }) == 2)
        #expect(migratedFloor.nodeIDs.allSatisfy { !$0.contains("ironGalleries") })
    }

    @Test func `preserves run health across map version regeneration`() throws {
        var legacy = try makeVersionFourState(seed: 9, clearedNodeCount: 2)
        legacy.runHealthByCombatantID = ["knight": 7, "wolf": 4]

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(legacy)

        #expect(sanitized.runHealthByCombatantID == ["knight": 7, "wolf": 4])
        #expect(sanitized.mapVersion == LabyrinthGenerator.currentMapVersion)
    }

    private func makeVersionFourState(
        seed: UInt64,
        clearedNodeCount: Int,
    ) throws -> PlayerLabyrinthState {
        let generated = LabyrinthGenerator.makeInitialMap(seed: seed)
        let floor = try #require(generated.clusters.first { $0.depthBand == 1 })
        let clusterID = "labyrinth-cluster-1-ironGalleries"
        let renamedIDs = Dictionary(uniqueKeysWithValues: floor.nodeIDs.enumerated().map { index, id in
            (id, "\(clusterID)-n\(index)")
        })
        let nodeEntries: [(String, LabyrinthNode)] = floor.nodeIDs.enumerated().compactMap { index, id in
            guard let node = generated.nodes[id], let renamedID = renamedIDs[id] else { return nil }
            return (
                renamedID,
                LabyrinthNode(
                    id: renamedID,
                    type: node.type,
                    enemyID: node.enemyID,
                    depth: node.depth,
                    clusterID: clusterID,
                    gridPosition: node.gridPosition,
                    modifierIDs: node.modifierIDs,
                    recruitEventID: node.recruitEventID,
                    mysteryEventID: node.mysteryEventID,
                    outgoingIDs: node.outgoingIDs.compactMap { renamedIDs[$0] },
                    isCleared: index < clearedNodeCount,
                    isRevealed: node.isRevealed,
                ),
            )
        }
        var nodes = Dictionary(uniqueKeysWithValues: nodeEntries)
        let legacyEntryID = try #require(renamedIDs[floor.nodeIDs[0]])
        nodes[LabyrinthGenerator.entranceNodeID] = LabyrinthNode(
            id: LabyrinthGenerator.entranceNodeID,
            type: .entrance,
            depth: 0,
            clusterID: LabyrinthGenerator.entranceClusterID,
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            outgoingIDs: [legacyEntryID],
            isCleared: true,
            isRevealed: true,
        )
        return PlayerLabyrinthState(
            worldSeed: seed,
            mapVersion: 4,
            hasEntered: true,
            clusters: [
                LabyrinthCluster(
                    id: LabyrinthGenerator.entranceClusterID,
                    depthBand: 0,
                    nodeIDs: [LabyrinthGenerator.entranceNodeID],
                ),
                LabyrinthCluster(
                    id: clusterID,
                    depthBand: 1,
                    nodeIDs: floor.nodeIDs.compactMap { renamedIDs[$0] },
                ),
            ],
            nodes: nodes,
        )
    }
}
