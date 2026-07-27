import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite("LabyrinthProgress")
struct LabyrinthProgressTests {
    private func makeWardenSave(seed: UInt64) -> PlayerSave {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: seed)
        let nodeID = "labyrinth-test-warden-" + String(seed)
        save.labyrinth.nodes[nodeID] = LabyrinthNode(
            id: nodeID,
            type: .boss,
            enemyID: "the_frostwarden",
            depth: 3,
            clusterID: "labyrinth-test",
            isRevealed: true
        )
        return save
    }

    @Test func ensureMapCreatesReachableNodes() {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 99)
        #expect(state.hasMap)
        #expect(state.hasEntered)
        #expect(!state.reachableNodeIDs().isEmpty)
    }

    @Test func markClearedExpandsPastBossAndKeepsEarlierNodes() throws {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 21)
        var boss = try #require(state.nodes.values.first(where: { $0.type == .boss && $0.depth == 1 }), "Missing floor-1 boss")
        let unfinishedID = state.nodes.values.first(where: {
            $0.depth == 1 && $0.id != boss.id && !$0.isCleared
        })?.id
        boss.isRevealed = true
        state.nodes[boss.id] = boss
        if var entrance = state.nodes[LabyrinthGenerator.entranceNodeID] {
            if !entrance.outgoingIDs.contains(boss.id) {
                entrance.outgoingIDs.append(boss.id)
                state.nodes[entrance.id] = entrance
            }
        }
        state.markCleared(nodeID: boss.id)
        #expect(state.nodes[boss.id]?.isCleared == true)
        #expect(state.clusters.contains { $0.depthBand == 2 })
        #expect(state.currentFloorNumber == 2)
        state.markCleared(nodeID: boss.id)
        #expect(state.currentFloorNumber == 2)
        if let unfinishedID {
            #expect(state.nodes[unfinishedID]?.isCleared == false)
        }
    }

    @Test func sanitizeMigratesLegacyFloorLayoutGateAndModifiers() throws {
        let generated = LabyrinthGenerator.makeMap(seed: 9, floorCount: 3)
        var legacy = PlayerLabyrinthState(
            worldSeed: 9,
            mapVersion: 2,
            hasEntered: true,
            clusters: generated.clusters,
            nodes: generated.nodes
        )
        let thirdFloor = try #require(legacy.clusters.first { $0.depthBand == 3 })
        let clearedID = try #require(thirdFloor.nodeIDs.first)
        var cleared = try #require(legacy.nodes[clearedID])
        cleared.isCleared = true
        legacy.nodes[clearedID] = LabyrinthNode(
            id: cleared.id,
            type: cleared.type,
            enemyID: cleared.enemyID,
            depth: cleared.depth,
            clusterID: cleared.clusterID,
            gridPosition: LabyrinthGridPosition(row: 99, column: 99),
            modifierIDs: [LabyrinthModifierID("bossMark"), LabyrinthModifierID("ironPressure")],
            recruitEventID: cleared.recruitEventID,
            outgoingIDs: cleared.outgoingIDs,
            isCleared: true,
            isRevealed: true
        )

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(legacy)
        let migrated = try #require(sanitized.nodes[clearedID])
        #expect(sanitized.mapVersion == LabyrinthGenerator.currentMapVersion)
        #expect(migrated.isCleared)
        #expect(migrated.gridPosition != LabyrinthGridPosition(row: 99, column: 99))
        #expect(migrated.modifierIDs.count == 1)
        #expect(migrated.modifierIDs.first?.rawValue != "bossMark")
        let clusterModifierIDs = sanitized.clusters.map(\.modifierIDs)
        let hasNoLegacyClusterModifiers = clusterModifierIDs.allSatisfy(\.isEmpty)
        #expect(hasNoLegacyClusterModifiers)
        for floor in 1 ... 2 {
            let cluster = try #require(sanitized.clusters.first { $0.depthBand == floor })
            let entryID = try #require(cluster.nodeIDs.first)
            let bossID = try #require(cluster.nodeIDs.last)
            #expect(sanitized.nodes[bossID]?.isCleared == true)
            #expect(
                hasClearedAdjacentPath(
                    from: entryID,
                    to: bossID,
                    nodeIDs: cluster.nodeIDs,
                    state: sanitized
                )
            )
        }
    }

    @Test @MainActor func labyrinthPersistsThroughStore() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "labyrinth-progress")
        defer { SaveTestSupport.removeTempDirectory(directory) }

        let first = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        var progress = first.labyrinth
        progress.ensureMap(seed: 55)
        let firstReachable = try #require(progress.reachableNodeIDs().first)
        progress.markCleared(nodeID: firstReachable)
        first.labyrinth = progress

        let second = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        #expect(second.labyrinth.hasMap)
        #expect(second.labyrinth.nodes[firstReachable]?.isCleared == true)
        #expect(second.labyrinth.worldSeed == 55)
    }

    @Test func completionGrantsGoldAndClearsNode() throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 17)
        let nodeID = try #require(save.labyrinth.reachableNodeIDs().first)
        let goldBefore = save.roster.gold
        LabyrinthCompletion.complete(
            nodeID: nodeID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            save: &save
        )
        #expect(save.labyrinth.nodes[nodeID]?.isCleared == true)
        #expect(save.roster.gold >= goldBefore)
    }

    @Test(arguments: [false, true])
    func completionGrantsBattleExperienceOnlyForCombatNodes(isCombat: Bool) throws {
        var save = PlayerSave.fresh
        if isCombat {
            save.labyrinth.ensureMap(seed: 31)
            let combatID = try #require(
                save.labyrinth.reachableNodeIDs().first(where: {
                    save.labyrinth.nodes[$0]?.type.isCombat == true
                })
            )
            let heroXPBefore = save.roster.progression(for: save.roster.activeHero)
            LabyrinthCompletion.complete(
                nodeID: combatID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
            let heroXPAfter = save.roster.progression(for: save.roster.activeHero)
            #expect(
                heroXPAfter.level > heroXPBefore.level
                    || heroXPAfter.currentXP > heroXPBefore.currentXP
            )
        } else {
            save.labyrinth.ensureMap(seed: 23)
            let restID = "labyrinth-audit-rest"
            save.labyrinth.nodes[restID] = LabyrinthNode(
                id: restID,
                type: .rest,
                enemyID: nil,
                depth: 2,
                clusterID: "audit",
                outgoingIDs: [],
                isCleared: false,
                isRevealed: true
            )
            if var entrance = save.labyrinth.nodes[LabyrinthGenerator.entranceNodeID] {
                entrance.outgoingIDs.append(restID)
                save.labyrinth.nodes[entrance.id] = entrance
            }

            let heroXPBefore = save.roster.progression(for: save.roster.activeHero)
            let companionXPBefore = save.roster.progression(for: save.roster.activeCompanion)
            LabyrinthCompletion.complete(
                nodeID: restID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
            #expect(save.labyrinth.nodes[restID]?.isCleared == true)
            #expect(save.roster.progression(for: save.roster.activeHero) == heroXPBefore)
            #expect(save.roster.progression(for: save.roster.activeCompanion) == companionXPBefore)
        }
    }

    @Test func sanitizeCollapsesLegacyEventNodesToMystery() throws {
        var dirty = PlayerLabyrinthState.freshStart
        dirty.ensureMap(seed: 4)
        let nodeID = try #require(dirty.reachableNodeIDs().first ?? dirty.nodes.keys.min())
        if let node = dirty.nodes[nodeID] {
            dirty.nodes[nodeID] = LabyrinthNode(
                id: node.id,
                type: .event,
                enemyID: nil,
                depth: node.depth,
                clusterID: node.clusterID,
                outgoingIDs: node.outgoingIDs,
                isCleared: node.isCleared,
                isRevealed: true
            )
        }
        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(dirty)
        #expect(sanitized.nodes[nodeID]?.type == .mystery)
    }

    @Test(arguments: [true, false])
    func craftNodeCompletionRespectsForgeChoice(forge: Bool) throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 19)
        var craftID: String?
        for _ in 0 ..< 40 {
            if let id = save.labyrinth.reachableNodeIDs().first(where: {
                save.labyrinth.nodes[$0]?.type.canonical == .craft
            }) {
                craftID = id
                break
            }
            guard let next = save.labyrinth.reachableNodeIDs().first else { break }
            LabyrinthCompletion.complete(
                nodeID: next,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
        }
        let nodeID = try #require(craftID)
        let itemsBefore = save.inventory.items.count
        let goldBefore = save.roster.gold

        if forge {
            save.roster.grantGold(200)
            let goldWithBudget = save.roster.gold
            let forged = LabyrinthCompletion.forgeAtAltar(
                nodeID: nodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
            #expect(forged)
            #expect(save.labyrinth.nodes[nodeID]?.isCleared == true)
            #expect(save.roster.gold < goldWithBudget)
            #expect(save.inventory.items.count == itemsBefore + 1)
        } else {
            LabyrinthCompletion.complete(
                nodeID: nodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
            #expect(save.labyrinth.nodes[nodeID]?.isCleared == true)
            #expect(save.inventory.items.count == itemsBefore)
            #expect(save.roster.gold > goldBefore)
        }
    }

    @Test func gildedWhisperRoundsPositiveGoldBonusUp() {
        let node = LabyrinthNode(
            id: "gilded-shop",
            type: .shop,
            depth: 1,
            clusterID: "gilded",
            modifierIDs: [LabyrinthModifierID("gildedWhisper")]
        )
        let effects = LabyrinthModifierEffects.combining(
            LabyrinthCatalog.modifiers(ids: node.modifierIDs),
            biomeBias: .gold
        )
        #expect(LabyrinthCompletion.nonCombatGoldStipend(for: node, effects: effects) == 4)
    }

    @Test func pendingCombatRewardItemMatchesCompletionGrantForBoss() throws {
        var save = makeWardenSave(seed: 41)
        let bossID = "labyrinth-test-warden-41"
        let boss = try #require(save.labyrinth.nodes[bossID])

        let effects = save.labyrinth.effects(for: bossID)
        let pending = try #require(
            LabyrinthCompletion.pendingCombatRewardItem(
                for: boss,
                effects: effects,
                worldSeed: save.labyrinth.worldSeed
            )
        )
        #expect(pending.id == LabyrinthCompletion.rewardItemID(forNodeID: bossID))
        #expect(pending.rarity == .astral)

        LabyrinthCompletion.complete(
            nodeID: bossID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            rewardItem: pending,
            save: &save
        )
        #expect(save.inventory.items.contains(where: { $0.id == pending.id }))
        #expect(save.inventory.items.count(where: { $0.id == pending.id }) == 1)
    }

    @Test func corruptMapPayloadClearsTopologyThenSanitizeRebuilds() {
        let model = LabyrinthProgressModel()
        model.worldSeed = 55
        model.hasEntered = true
        model.mapPayload = Data("{not-valid-labyrinth-json".utf8)

        let loaded = model.toPlayerLabyrinthState()
        #expect(loaded.nodes.isEmpty)
        #expect(loaded.clusters.isEmpty)
        #expect(loaded.hasEntered)
        #expect(loaded.worldSeed == 55)

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(loaded)
        #expect(sanitized.hasMap)
        #expect(!sanitized.nodes.isEmpty)
        #expect(sanitized.worldSeed == 55)
    }

    @Test func mapUpdatePreservesPriorPayloadWhenReencodingSameState() throws {
        let model = LabyrinthProgressModel()
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 77)
        model.update(from: state)
        let firstPayload = try #require(model.mapPayload)

        model.update(from: state)
        let secondPayload = try #require(model.mapPayload)
        let firstMap = try JSONDecoder().decode(LabyrinthMapPayload.self, from: firstPayload)
        let secondMap = try JSONDecoder().decode(LabyrinthMapPayload.self, from: secondPayload)
        #expect(secondMap == firstMap)

        let reloaded = model.toPlayerLabyrinthState()
        #expect(reloaded.nodes.count == state.nodes.count)
        #expect(reloaded.worldSeed == 77)
    }

    @Test func labyrinthHydrationToleratesDuplicateNodeIDs() throws {
        let model = LabyrinthProgressModel()
        model.worldSeed = 9
        model.hasEntered = true
        let first = LabyrinthNode(
            id: "dup-node",
            type: .battle,
            enemyID: "slime",
            depth: 1,
            clusterID: "cluster",
            isRevealed: true
        )
        let second = LabyrinthNode(
            id: "dup-node",
            type: .battle,
            enemyID: "skeleton",
            depth: 1,
            clusterID: "cluster",
            isRevealed: true
        )
        model.mapPayload = try JSONEncoder().encode(
            LabyrinthMapPayload(clusters: [], nodes: [first, second])
        )

        let loaded = model.toPlayerLabyrinthState()
        #expect(loaded.nodes.count == 1)
        #expect(loaded.nodes["dup-node"]?.enemyID == "skeleton")
    }
}

private extension LabyrinthProgressTests {
    func hasClearedAdjacentPath(
        from sourceID: String,
        to targetID: String,
        nodeIDs: [String],
        state: PlayerLabyrinthState
    ) -> Bool {
        var reached = Set([sourceID])
        var frontier = [sourceID]
        while let nodeID = frontier.popLast() {
            guard let source = state.nodes[nodeID] else { continue }
            for candidateID in nodeIDs where !reached.contains(candidateID) {
                guard let candidate = state.nodes[candidateID],
                      candidate.isCleared,
                      areAdjacent(source, candidate)
                else { continue }
                reached.insert(candidateID)
                frontier.append(candidateID)
            }
        }
        return reached.contains(targetID)
    }

    func areAdjacent(_ source: LabyrinthNode, _ target: LabyrinthNode) -> Bool {
        guard let sourcePosition = source.gridPosition,
              let targetPosition = target.gridPosition
        else { return false }
        let rowDelta = targetPosition.row - sourcePosition.row
        let columnDelta = targetPosition.column - sourcePosition.column
        return (rowDelta == 0 && abs(columnDelta) == 1)
            || (rowDelta == 1 && (columnDelta == 0 || columnDelta == -1))
            || (rowDelta == -1 && (columnDelta == 0 || columnDelta == 1))
    }
}

extension LabyrinthProgressTests {
    @Test func clearedHexMakesAllSixNeighborDirectionsReachable() {
        let center = LabyrinthNode(
            id: "center",
            type: .battle,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 0),
            isCleared: true,
            isRevealed: true
        )
        let neighborPositions = [
            "left": LabyrinthGridPosition(row: 1, column: -1),
            "right": LabyrinthGridPosition(row: 1, column: 1),
            "upLeft": LabyrinthGridPosition(row: 0, column: 0),
            "upRight": LabyrinthGridPosition(row: 0, column: 1),
            "downLeft": LabyrinthGridPosition(row: 2, column: -1),
            "downRight": LabyrinthGridPosition(row: 2, column: 0),
        ]
        let neighbors = neighborPositions.map { id, position in
            LabyrinthNode(
                id: id,
                type: .mystery,
                depth: 1,
                clusterID: "floor",
                gridPosition: position,
                isRevealed: true
            )
        }
        let distant = LabyrinthNode(
            id: "distant",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 3, column: 0),
            isRevealed: true
        )
        let otherFloor = LabyrinthNode(
            id: "other-floor",
            type: .mystery,
            depth: 2,
            clusterID: "other-floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 1),
            isRevealed: true
        )
        let allNodes = [center, distant, otherFloor] + neighbors
        let state = PlayerLabyrinthState(
            hasEntered: true,
            nodes: Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0) })
        )

        for neighbor in neighbors {
            #expect(state.isNodeReachable(neighbor.id))
        }
        #expect(!state.isNodeReachable(distant.id))
        #expect(!state.isNodeReachable(otherFloor.id))
    }
}

extension LabyrinthProgressTests {
    @Test func legacyWireAtlasFieldsAreIgnoredAndNotResaved() throws {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 91)
        let currentData = try JSONEncoder().encode(WireLabyrinthState(state))
        var object = try #require(
            JSONSerialization.jsonObject(with: currentData) as? [String: Any]
        )
        object["deepestDepth"] = 50
        object["discoveredBiomeIDs"] = ["scarCatacombs"]
        object["discoveredModifierIDs"] = ["ironPressure"]
        object["claimedMilestoneDepths"] = [5, 10, 25, 50]
        object.removeValue(forKey: "mapVersion")
        if var nodes = object["nodes"] as? [[String: Any]], !nodes.isEmpty {
            nodes[0]["failCount"] = 4
            object["nodes"] = nodes
        }

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(WireLabyrinthState.self, from: legacyData)
        let loaded = decoded.labyrinth()

        #expect(loaded.clusters == state.clusters)
        #expect(loaded.nodes == state.nodes)
        #expect(loaded.mapVersion == 1)

        let resaved = try JSONEncoder().encode(decoded)
        let resavedObject = try #require(
            JSONSerialization.jsonObject(with: resaved) as? [String: Any]
        )
        #expect(resavedObject["deepestDepth"] == nil)
        #expect(resavedObject["discoveredBiomeIDs"] == nil)
        #expect(resavedObject["discoveredModifierIDs"] == nil)
        #expect(resavedObject["claimedMilestoneDepths"] == nil)
        let resavedNodes = try #require(resavedObject["nodes"] as? [[String: Any]])
        let omitsFailureCounts = resavedNodes.allSatisfy { $0["failCount"] == nil }
        #expect(omitsFailureCounts)
    }

    @Test func depthFiveCompletionGrantsNoMilestoneBonus() {
        let node = LabyrinthNode(
            id: "depth-five-rest",
            type: .rest,
            depth: 5,
            clusterID: "depth-five",
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            isRevealed: true
        )
        let cluster = LabyrinthCluster(
            id: node.clusterID,
            biomeID: .scarCatacombs,
            depthBand: 5,
            modifierIDs: [],
            nodeIDs: [node.id]
        )
        var save = PlayerSave.fresh
        save.labyrinth = PlayerLabyrinthState(
            worldSeed: 5,
            hasEntered: true,
            clusters: [cluster],
            nodes: [node.id: node]
        )
        let expectedGold = LabyrinthCompletion.nonCombatGoldStipend(
            for: node,
            effects: save.labyrinth.effects(for: node.id)
        )
        let goldBefore = save.roster.gold

        LabyrinthCompletion.complete(
            nodeID: node.id,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            save: &save
        )

        #expect(save.roster.gold == goldBefore + expectedGold)
    }
}
