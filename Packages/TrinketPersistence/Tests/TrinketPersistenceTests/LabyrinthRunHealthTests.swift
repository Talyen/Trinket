import Foundation
import Testing
import TrinketContent
@testable import TrinketPersistence

struct LabyrinthRunHealthTests {
    @Test func `campfire rest health restores floored thirty percent capped at max`() {
        #expect(LabyrinthCompletion.campfireRestHealth(current: 34, maxHealth: 52) == 49)
        #expect(LabyrinthCompletion.campfireRestHealth(current: 0, maxHealth: 41) == 12)
        #expect(LabyrinthCompletion.campfireRestHealth(current: 90, maxHealth: 100) == 100)
        #expect(LabyrinthCompletion.campfireRestHealth(current: 100, maxHealth: 100) == 100)
    }

    @Test func `rest completion grants no gold stipend`() {
        let node = LabyrinthNode(
            id: "depth-five-rest",
            type: .rest,
            depth: 5,
            clusterID: "depth-five",
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            isRevealed: true,
        )
        let cluster = LabyrinthCluster(
            id: node.clusterID,
            depthBand: 5,
            nodeIDs: [node.id],
        )
        var save = PlayerSave.fresh
        save.labyrinth = PlayerLabyrinthState(
            worldSeed: 5,
            hasEntered: true,
            clusters: [cluster],
            nodes: [node.id: node],
        )
        let goldBefore = save.roster.gold

        LabyrinthCompletion.complete(
            nodeID: node.id,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            save: &save,
        )

        #expect(save.roster.gold == goldBefore)
    }

    @Test func `completion persists party run health`() throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 17)
        let combatID = try #require(
            save.labyrinth.reachableNodeIDs().first(where: {
                save.labyrinth.nodes[$0]?.type.isCombat == true
            }),
        )
        LabyrinthCompletion.complete(
            nodeID: combatID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            partyRunHealth: ["knight": 7],
            save: &save,
        )
        #expect(save.labyrinth.runHealthByCombatantID == ["knight": 7])
    }

    @Test func `ensure map resets run health`() {
        var progress = PlayerLabyrinthState.freshStart
        progress.runHealthByCombatantID = ["knight": 3]

        progress.ensureMap(seed: 55)

        #expect(progress.hasMap)
        #expect(progress.runHealthByCombatantID.isEmpty)
    }

    @Test func `map payload round trips run health and legacy blobs decode empty`() throws {
        let model = LabyrinthProgressModel()
        model.worldSeed = 9
        model.hasEntered = true
        let node = LabyrinthNode(
            id: "health-node",
            type: .rest,
            depth: 1,
            clusterID: "cluster",
            isRevealed: true,
        )
        model.mapPayload = try JSONEncoder().encode(
            LabyrinthMapPayload(clusters: [], nodes: [node], runHealthByCombatantID: ["knight": 12]),
        )
        #expect(model.toPlayerLabyrinthState().runHealthByCombatantID == ["knight": 12])

        let blob = try #require(model.mapPayload)
        var legacyObject = try #require(JSONSerialization.jsonObject(with: blob) as? [String: Any], "Unexpected payload shape")
        legacyObject.removeValue(forKey: "runHealthByCombatantID")
        let legacyBlob = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyPayload = try JSONDecoder().decode(LabyrinthMapPayload.self, from: legacyBlob)
        #expect(legacyPayload.runHealthByCombatantID.isEmpty)

        model.update(from: PlayerLabyrinthState(
            worldSeed: 9,
            hasEntered: true,
            clusters: [],
            nodes: [node.id: node],
            runHealthByCombatantID: ["wolf": 4],
        ))
        let reloaded = model.toPlayerLabyrinthState()
        #expect(reloaded.runHealthByCombatantID == ["wolf": 4])
    }
}
