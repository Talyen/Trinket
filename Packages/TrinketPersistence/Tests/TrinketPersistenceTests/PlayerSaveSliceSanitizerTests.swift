import Testing
import TrinketContent
import TrinketCore
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

    @Test func rosterSanitizeTargetsAlsoNormalizeLabyrinth() {
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
        let expanded = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: .sanitizeTargets(for: [.roster])
        )
        let rosterOnly = PlayerSaveSanitizer.sanitize(
            save,
            changedSlices: [.roster]
        )

        #expect(full == expanded)
        #expect(expanded.labyrinth.nodes[nodeID]?.type == .mystery)
        #expect(rosterOnly.labyrinth.nodes[nodeID]?.type == .event)
    }
}
