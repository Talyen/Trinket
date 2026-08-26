import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSliceSanitizerTests {
    @Test func sliceScopedSanitizeMatchesFullSanitizeForHomesteadMutation() {
        var save = PlayerSave.fresh
        save.homestead.pendingProduction[.wood] = 12.5

        let full = PlayerSaveSanitizer.sanitize(save)
        let scoped = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.homestead])
        )

        #expect(full == scoped)
    }

    @Test func sliceScopedSanitizeMatchesFullSanitizeForInventoryMutation() throws {
        let weaponBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .weapon })
        let weapon = InventoryItem(
            id: "weapon-id",
            templateID: "weapon-template",
            baseType: weaponBase,
            rarity: .basic,
            displayName: "Test Sword",
            affixes: []
        )
        var save = PlayerSave.fresh
        save.inventory = PlayerInventoryState(items: [weapon])

        let full = PlayerSaveSanitizer.sanitize(save)
        let scoped = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.inventory])
        )

        #expect(full == scoped)
    }

    @Test func sliceScopedSanitizeMatchesFullSanitizeForRosterMutation() {
        var save = PlayerSave.fresh
        save.roster.gold = 999999

        let full = PlayerSaveSanitizer.sanitize(save)
        let scoped = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.roster])
        )

        #expect(full == scoped)
    }

    @Test func sliceScopedSanitizeMatchesFullSanitizeForLabyrinthMutation() {
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
            isRevealed: true
        )

        let full = PlayerSaveSanitizer.sanitize(save)
        let scoped = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.labyrinth])
        )

        #expect(full == scoped)
        #expect(full.labyrinth.nodes[nodeID]?.type == .mystery)
    }

    @Test func inventoryAndRosterSanitizeTargetsDoNotExpandToLabyrinth() {
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.inventory]) == [.inventory, .roster])
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.roster]) == [.roster])
        #expect(PlayerSaveSlice.sanitizeTargets(for: [.labyrinth]) == [.labyrinth])
    }

    @Test func rosterSanitizeLeavesLabyrinthNodesForExplicitLabyrinthSlice() {
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
            isRevealed: true
        )
        save.roster.gold = 40

        let full = PlayerSaveSanitizer.sanitize(save)
        let rosterExpanded = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.roster])
        )

        #expect(full.labyrinth.nodes[nodeID]?.type == .mystery)
        #expect(rosterExpanded.labyrinth.nodes[nodeID]?.type == .event)
    }

    @Test func persistTargetsIncludeLabyrinthSeedPinAfterHomesteadMutation() {
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
            within: PlayerSaveSlice.persistTargets(for: sanitizeSlices)
        )

        #expect(mutationSlices == .homestead)
        #expect(!sanitizeSlices.contains(.labyrinth))
        #expect(candidate.labyrinth.worldSeed == candidate.worldSeed)
        #expect(changedSlices.contains(.labyrinth))
    }

    @Test func homesteadMutationPersistsSanitizerLabyrinthWorldSeedPin() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
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
