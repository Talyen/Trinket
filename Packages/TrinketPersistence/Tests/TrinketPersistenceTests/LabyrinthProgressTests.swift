import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
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

    @Test func markClearedExpandsPastGate() {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 21)
        let reachable = state.reachableNodeIDs()
        #expect(!reachable.isEmpty)

        // Clear all non-gate reachable nodes first if needed, then clear toward gate.
        // Directly clear a depth-1 gate after revealing it.
        guard var gate = state.nodes.values.first(where: { $0.type == .gate && $0.depth == 1 }) else {
            Issue.record("Missing depth-1 gate")
            return
        }
        gate.isRevealed = true
        state.nodes[gate.id] = gate
        // Make reachable by linking from a cleared node.
        if var entrance = state.nodes[LabyrinthGenerator.entranceNodeID] {
            if !entrance.outgoingIDs.contains(gate.id) {
                entrance.outgoingIDs.append(gate.id)
                state.nodes[entrance.id] = entrance
            }
        }
        state.markCleared(nodeID: gate.id)
        #expect(state.nodes[gate.id]?.isCleared == true)
        #expect(state.clusters.contains { $0.depthBand == 2 })
        #expect(state.deepestDepth >= 1)
    }

    @Test func sanitizeDropsUnknownBiomeAndModifierIDs() {
        var dirty = PlayerLabyrinthState.freshStart
        dirty.ensureMap(seed: 3)
        dirty.discoveredBiomeIDs.insert("missing-biome")
        dirty.discoveredModifierIDs.insert("missing-modifier")
        dirty.claimedMilestoneDepths.insert(999)
        let sanitized = PlayerSaveSanitizer.sanitizeLabyrinth(dirty)
        #expect(!sanitized.discoveredBiomeIDs.contains("missing-biome"))
        #expect(!sanitized.discoveredModifierIDs.contains("missing-modifier"))
        #expect(!sanitized.claimedMilestoneDepths.contains(999))
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
                isRevealed: true,
                failCount: 0
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

    @Test func recordDefeatIncrementsFailCountWithoutClearing() throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 8)
        let nodeID = try #require(save.labyrinth.reachableNodeIDs().first)
        LabyrinthCompletion.recordDefeat(nodeID: nodeID, save: &save)
        #expect(save.labyrinth.nodes[nodeID]?.failCount == 1)
        #expect(save.labyrinth.nodes[nodeID]?.isCleared == false)
    }

    @Test func sanitizeCollapsesLegacyEventNodesToMystery() throws {
        var dirty = PlayerLabyrinthState.freshStart
        dirty.ensureMap(seed: 4)
        let nodeID = try #require(dirty.reachableNodeIDs().first ?? dirty.nodes.keys.sorted().first)
        if let node = dirty.nodes[nodeID] {
            dirty.nodes[nodeID] = LabyrinthNode(
                id: node.id,
                type: .event,
                enemyID: nil,
                depth: node.depth,
                clusterID: node.clusterID,
                outgoingIDs: node.outgoingIDs,
                isCleared: node.isCleared,
                isRevealed: true,
                failCount: node.failCount
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

    @Test func adjustedExperienceAwardAppliesModifierPercent() {
        #expect(LabyrinthCompletion.adjustedExperienceAward(50, xpPercent: 0) == 50)
        #expect(LabyrinthCompletion.adjustedExperienceAward(50, xpPercent: 20) == 60)
        #expect(LabyrinthCompletion.adjustedExperienceAward(0, xpPercent: 20) == 0)
        #expect(LabyrinthCompletion.adjustedExperienceAward(-5, xpPercent: 20) == 0)
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
        #expect(save.inventory.items.filter { $0.id == pending.id }.count == 1)
    }

    @Test func corruptMapPayloadClearsTopologyThenSanitizeRebuilds() {
        let model = LabyrinthProgressModel()
        model.worldSeed = 55
        model.hasEntered = true
        model.deepestDepth = 3
        model.mapPayload = Data("{not-valid-labyrinth-json".utf8)

        let loaded = model.toPlayerLabyrinthState()
        #expect(loaded.nodes.isEmpty)
        #expect(loaded.clusters.isEmpty)
        #expect(loaded.hasEntered)
        #expect(loaded.worldSeed == 55)
        #expect(loaded.deepestDepth == 3)

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
            isRevealed: true,
            failCount: 0
        )
        let second = LabyrinthNode(
            id: "dup-node",
            type: .battle,
            enemyID: "slime",
            depth: 1,
            clusterID: "cluster",
            isRevealed: true,
            failCount: 2
        )
        model.mapPayload = try JSONEncoder().encode(
            LabyrinthMapPayload(clusters: [], nodes: [first, second])
        )

        let loaded = model.toPlayerLabyrinthState()
        #expect(loaded.nodes.count == 1)
        #expect(loaded.nodes["dup-node"]?.failCount == 2)
    }
}
