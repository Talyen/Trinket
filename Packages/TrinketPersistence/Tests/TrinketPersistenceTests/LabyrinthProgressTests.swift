import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
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
            isRevealed: true,
        )
        return save
    }

    @Test func `ensure map without seed does not use fallback`() {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap()
        #expect(!state.hasMap)
        #expect(state.worldSeed == 0)
    }

    @Test func `ensure map creates reachable nodes`() {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 99)
        #expect(state.hasMap)
        #expect(state.hasEntered)
        #expect(!state.reachableNodeIDs().isEmpty)
    }

    @Test func `mark cleared expands past boss and keeps earlier nodes`() throws {
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

    @Test func `sanitize migrates legacy floor layout gate and modifiers`() throws {
        let generated = LabyrinthGenerator.makeMap(seed: 9, floorCount: 3)
        var legacy = PlayerLabyrinthState(
            worldSeed: 9,
            mapVersion: 2,
            hasEntered: true,
            clusters: generated.clusters,
            nodes: generated.nodes,
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
            isRevealed: true,
        )

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(legacy)
        let migrated = try #require(sanitized.nodes[clearedID])
        #expect(sanitized.mapVersion == LabyrinthGenerator.currentMapVersion)
        #expect(migrated.isCleared)
        #expect(migrated.gridPosition != LabyrinthGridPosition(row: 99, column: 99))
        #expect(migrated.modifierIDs.count <= 1)
        #expect(migrated.modifierIDs.first?.rawValue != "bossMark")
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
                    state: sanitized,
                ),
            )
        }
    }

    @Test @MainActor func `labyrinth persists through store`() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "labyrinth-progress")
        defer { SaveTestSupport.removeTempDirectory(directory) }

        let first = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        var progress = first.labyrinth
        progress.ensureMap(seed: 55)
        let firstReachable = try #require(progress.reachableNodeIDs().first)
        progress.markCleared(nodeID: firstReachable)
        progress.runHealthByCombatantID = ["knight": 11, "wolf": 6]
        first.labyrinth = progress

        let second = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        #expect(second.labyrinth.hasMap)
        #expect(second.labyrinth.nodes[firstReachable]?.isCleared == true)
        #expect(second.labyrinth.worldSeed == 55)
        #expect(second.labyrinth.runHealthByCombatantID == ["knight": 11, "wolf": 6])
    }

    @Test func `completion grants gold and clears node`() throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 17)
        let nodeID = try #require(save.labyrinth.reachableNodeIDs().first)
        let goldBefore = save.roster.gold
        LabyrinthCompletion.complete(
            nodeID: nodeID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            save: &save,
        )
        #expect(save.labyrinth.nodes[nodeID]?.isCleared == true)
        #expect(save.roster.gold >= goldBefore)
    }

    @Test(arguments: [false, true])
    func `completion grants battle experience only for combat nodes`(isCombat: Bool) throws {
        var save = PlayerSave.fresh
        if isCombat {
            save.labyrinth.ensureMap(seed: 31)
            let combatID = try #require(
                save.labyrinth.reachableNodeIDs().first(where: {
                    save.labyrinth.nodes[$0]?.type.isCombat == true
                }),
            )
            let heroXPBefore = save.roster.progression(for: save.roster.activeHero)
            LabyrinthCompletion.complete(
                nodeID: combatID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save,
            )
            let heroXPAfter = save.roster.progression(for: save.roster.activeHero)
            #expect(
                heroXPAfter.level > heroXPBefore.level
                    || heroXPAfter.currentXP > heroXPBefore.currentXP,
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
                isRevealed: true,
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
                save: &save,
            )
            #expect(save.labyrinth.nodes[restID]?.isCleared == true)
            #expect(save.roster.progression(for: save.roster.activeHero) == heroXPBefore)
            #expect(save.roster.progression(for: save.roster.activeCompanion) == companionXPBefore)
        }
    }

    @Test func `labyrinth economy modifiers scale combat loot`() {
        let node = LabyrinthNode(
            id: "econ-node",
            type: .battle,
            enemyID: "goblin_scout",
            depth: 2,
            clusterID: "econ",
        )
        let resolve: (LabyrinthModifierEffects) -> BattleLootPackage = { effects in
            BattleLoot.resolveLabyrinth(
                node: node,
                encounterLevel: 3,
                enemyIsBoss: false,
                effects: effects,
                worldSeed: 5,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
            )
        }

        let base = resolve(.zero)
        #expect(base.gold > 0)
        #expect(!base.materials.isEmpty)

        let bounty = resolve(LabyrinthModifierEffects.combining(
            LabyrinthCatalog.modifiers(ids: [LabyrinthModifierID("bountyMark")]),
        ))
        #expect(bounty.gold == base.gold + (base.gold * 25) / 100)
        #expect(bounty.materials == base.materials)

        let scavenger = resolve(LabyrinthModifierEffects.combining(
            LabyrinthCatalog.modifiers(ids: [LabyrinthModifierID("scavengersLuck")]),
        ))
        #expect(scavenger.gold == base.gold)
        for (boosted, original) in zip(scavenger.materials, base.materials) {
            #expect(boosted.resource == original.resource)
            #expect(boosted.quantity == (original.quantity * 125) / 100)
        }
    }

    @Test func `pending combat reward item matches completion grant for boss`() throws {
        var save = makeWardenSave(seed: 41)
        let bossID = "labyrinth-test-warden-41"
        let boss = try #require(save.labyrinth.nodes[bossID])

        let effects = save.labyrinth.effects(for: bossID)
        let pendingLoot = try #require(
            LabyrinthCompletion.resolveCombatLoot(
                for: boss,
                effects: effects,
                worldSeed: save.labyrinth.worldSeed,
                ownedTrinketIDs: save.inventory.ownedTrinketIDs,
                ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            ),
        )
        let pending = pendingLoot.item
        #expect(pending.rarity != .basic)
        if pending.isTrinket || pending.rarity == .unique {
            #expect(pending.id == pending.templateID)
        } else {
            #expect(pending.rarity == .astral)
            #expect(pending.id == LabyrinthCompletion.rewardItemID(forNodeID: bossID))
        }

        LabyrinthCompletion.complete(
            nodeID: bossID,
            hero: save.roster.activeHero,
            companion: save.roster.activeCompanion,
            rewardItem: pending,
            save: &save,
        )
        #expect(save.inventory.items.contains(where: { $0.id == pending.id }))
        #expect(save.inventory.items.count(where: { $0.id == pending.id }) == 1)
    }

    @Test func `map update preserves prior payload when reencoding same state`() throws {
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

    @Test func `labyrinth hydration tolerates duplicate node I ds`() throws {
        let model = LabyrinthProgressModel()
        model.worldSeed = 9
        model.hasEntered = true
        let first = LabyrinthNode(
            id: "dup-node",
            type: .battle,
            enemyID: "slime",
            depth: 1,
            clusterID: "cluster",
            isRevealed: true,
        )
        let second = LabyrinthNode(
            id: "dup-node",
            type: .battle,
            enemyID: "skeleton",
            depth: 1,
            clusterID: "cluster",
            isRevealed: true,
        )
        model.mapPayload = try JSONEncoder().encode(
            LabyrinthMapPayload(clusters: [], nodes: [first, second]),
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
        state: PlayerLabyrinthState,
    ) -> Bool {
        var reached = Set([sourceID])
        var frontier = [sourceID]
        while let nodeID = frontier.popLast() {
            guard let source = state.nodes[nodeID] else { continue }
            for candidateID in nodeIDs where !reached.contains(candidateID) {
                guard let candidate = state.nodes[candidateID],
                      candidate.isCleared,
                      source.isAdjacent(to: candidate)
                else { continue }
                reached.insert(candidateID)
                frontier.append(candidateID)
            }
        }
        return reached.contains(targetID)
    }
}

extension LabyrinthProgressTests {
    @Test func `cleared hex makes adjacent neighbors reachable`() {
        let center = LabyrinthNode(
            id: "center",
            type: .battle,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 0),
            isCleared: true,
            isRevealed: true,
        )
        let neighborA = LabyrinthNode(
            id: "neighbor-a",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: -1),
            isRevealed: true,
        )
        let neighborB = LabyrinthNode(
            id: "neighbor-b",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 0, column: 1),
            isRevealed: true,
        )
        let distant = LabyrinthNode(
            id: "distant",
            type: .mystery,
            depth: 1,
            clusterID: "floor",
            gridPosition: LabyrinthGridPosition(row: 3, column: 0),
            isRevealed: true,
        )
        let otherFloor = LabyrinthNode(
            id: "other-floor",
            type: .mystery,
            depth: 2,
            clusterID: "other-floor",
            gridPosition: LabyrinthGridPosition(row: 1, column: 1),
            isRevealed: true,
        )
        let state = PlayerLabyrinthState(
            hasEntered: true,
            nodes: Dictionary(uniqueKeysWithValues: [center, neighborA, neighborB, distant, otherFloor].map { ($0.id, $0) }),
        )

        #expect(state.isNodeReachable(neighborA.id))
        #expect(state.isNodeReachable(neighborB.id))
        #expect(Set(state.reachableNodeIDs()) == Set([neighborA.id, neighborB.id]))
        #expect(!state.isNodeReachable(distant.id))
        #expect(!state.isNodeReachable(otherFloor.id))
    }
}

extension LabyrinthProgressTests {
    @Test func `corrupt map payload heals on sanitize rebuild`() {
        let model = LabyrinthProgressModel()
        model.worldSeed = 55
        model.hasEntered = true
        let corruptBlob = Data("{not-valid-labyrinth-json".utf8)
        model.mapPayload = corruptBlob

        let loaded = model.toPlayerLabyrinthState()
        #expect(loaded.nodes.isEmpty)
        #expect(loaded.clusters.isEmpty)
        #expect(loaded.hasEntered)
        #expect(loaded.worldSeed == 55)
        #expect(loaded.isMapPayloadUnreadable)

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(loaded)
        #expect(sanitized.hasMap)
        #expect(!sanitized.isMapPayloadUnreadable)
        #expect(sanitized.worldSeed == 55)

        model.update(from: sanitized)
        #expect(model.mapPayload != corruptBlob)
        #expect(!model.toPlayerLabyrinthState().isMapPayloadUnreadable)
    }

    @Test func `sanitize preserves pinned mystery on map version bump`() throws {
        let generated = LabyrinthGenerator.makeMap(seed: 9, floorCount: 3)
        var legacy = PlayerLabyrinthState(
            worldSeed: 9,
            mapVersion: 2,
            hasEntered: true,
            clusters: generated.clusters,
            nodes: generated.nodes,
        )
        let currentFloor = try #require(legacy.clusters.map(\.depthBand).max())
        let mysteryID = try #require(
            legacy.nodes.values.first {
                $0.type.canonical == .mystery && $0.depth == currentFloor
            }?.id,
        )
        var mystery = try #require(legacy.nodes[mysteryID])
        mystery.mysteryEventID = "hidden-cache"
        mystery.isRevealed = true
        legacy.nodes[mysteryID] = mystery

        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(legacy)
        let migrated = try #require(sanitized.nodes[mysteryID])
        #expect(migrated.mysteryEventID == "hidden-cache")
        #expect(migrated.isRevealed)
        #expect(!migrated.isCleared)
        #expect(sanitized.mapVersion == LabyrinthGenerator.currentMapVersion)
    }
}
