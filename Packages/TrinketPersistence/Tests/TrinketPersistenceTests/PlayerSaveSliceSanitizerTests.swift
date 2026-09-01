import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveSliceSanitizerTests {
    private enum SliceEqualityCase: String {
        case homestead
        case inventory
        case roster
        case labyrinth
    }

    @Test(arguments: [
        SliceEqualityCase.homestead,
        .inventory,
        .roster,
        .labyrinth,
    ])
    private func `slice scoped sanitize matches full sanitize`(_ sliceCase: SliceEqualityCase) throws {
        var save = PlayerSave.fresh
        let slice: PlayerSaveSlice
        var labyrinthNodeID: String?
        switch sliceCase {
        case .homestead:
            save.homestead.pendingProduction[.wood] = 12.5
            slice = .homestead
        case .inventory:
            let weaponBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
            save.inventory = PlayerInventoryState(items: [
                InventoryItem(
                    id: "weapon-id",
                    templateID: "weapon-template",
                    baseType: weaponBase,
                    rarity: .basic,
                    displayName: "Test Sword",
                    affixes: [],
                ),
            ])
            slice = .inventory
        case .roster:
            save.roster.gold = 999999
            slice = .roster
        case .labyrinth:
            save.labyrinth.ensureMap(seed: 4)
            let nodeID = try #require(save.labyrinth.reachableNodeIDs().first ?? save.labyrinth.nodes.keys.min())
            let node = try #require(save.labyrinth.nodes[nodeID])
            save.labyrinth.nodes[nodeID] = LabyrinthNode(
                id: node.id,
                type: .event,
                enemyID: nil,
                depth: node.depth,
                clusterID: node.clusterID,
                outgoingIDs: node.outgoingIDs,
                isCleared: node.isCleared,
                isRevealed: true,
            )
            slice = .labyrinth
            labyrinthNodeID = nodeID
        }

        let full = PlayerSaveSanitizer.sanitize(save)
        let scoped = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: slice),
        )

        #expect(full == scoped)
        if let labyrinthNodeID {
            #expect(full.labyrinth.nodes[labyrinthNodeID]?.type == .mystery)
        }
    }

    @Test func `inventory and roster sanitize targets do not expand to labyrinth`() {
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.inventory]) == [.inventory, .roster])
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.roster]) == [.roster])
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.labyrinth]) == [.labyrinth])
    }

    @Test func `roster sanitize leaves labyrinth nodes for explicit labyrinth slice`() {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 4)
        let nodeID = save.labyrinth.reachableNodeIDs().first ?? save.labyrinth.nodes.keys.min()
        guard let nodeID, let node = save.labyrinth.nodes[nodeID] else {
            Issue.record("Expected a generated labyrinth node")
            return
        }
        save.labyrinth.nodes[nodeID] = LabyrinthNode(
            id: node.id,
            type: .event,
            enemyID: nil,
            depth: node.depth,
            clusterID: node.clusterID,
            outgoingIDs: node.outgoingIDs,
            isCleared: node.isCleared,
            isRevealed: true,
        )
        save.roster.gold = 40

        let full = PlayerSaveSanitizer.sanitize(save)
        let rosterExpanded = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.roster]),
        )

        #expect(full.labyrinth.nodes[nodeID]?.type == .mystery)
        #expect(rosterExpanded.labyrinth.nodes[nodeID]?.type == .event)
    }

    @Test func `persist targets include labyrinth seed pin after homestead mutation`() {
        var snapshot = PlayerSave.fresh
        snapshot.labyrinth.worldSeed = 0
        var candidate = snapshot
        candidate.homestead.resources[.wood] = 4

        let mutationSlices = PlayerSaveSlice.changed(between: snapshot, and: candidate)
        let sanitizeSlices = PlayerSaveSlice.sanitizeTargets(for: mutationSlices)
        candidate = PlayerSaveSanitizer.sanitize(candidate, changedSlices: sanitizeSlices)
        let changedSlices = PlayerSaveSlice.changed(
            between: snapshot,
            and: candidate,
            within: PlayerSaveSlice.persistTargets(for: sanitizeSlices),
        )

        #expect(mutationSlices == .homestead)
        #expect(!sanitizeSlices.contains(.labyrinth))
        #expect(candidate.labyrinth.worldSeed == candidate.worldSeed)
        #expect(changedSlices.contains(.labyrinth))
    }

    @Test @MainActor func `homestead mutation persists sanitizer labyrinth world seed pin`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        var snapshot = store.currentSave
        snapshot.labyrinth.worldSeed = 0
        let wood = (snapshot.homestead.resources[.wood] ?? 0) + 1
        let (candidate, changedSlices) = try PlayerSaveSlice.prepareCandidate(from: snapshot) { save in
            save.homestead.resources[.wood] = wood
        }
        #expect(changedSlices.contains(.labyrinth))
        #expect(candidate.labyrinth.worldSeed == candidate.worldSeed)
        #expect(candidate.labyrinth.worldSeed != 0)

        try store.performBatchMutation { $0 = candidate }
        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(reloaded.labyrinth.worldSeed == reloaded.worldSeed)
        #expect(reloaded.homestead.resources[.wood] == wood)
    }
}
