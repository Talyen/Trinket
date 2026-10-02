import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct MysteryMaterialBoundaryTests {
    @Test(arguments: [Int.min, 0, 1, 3, 4, 7, 50, Int.max / 14, Int.max / 14 + 1, Int.max])
    func `material scaling preserves the exact quotient across integer boundaries`(level: Int) {
        let product = UInt(max(1, level)).multipliedFullWidth(by: 14)
        let quotient = UInt(49).dividingFullWidth(product).quotient
        #expect(MysteryEffectApplier.materialQuantity(forLevel: level) == 4 + Int(quotient))
    }

    @Test @MainActor func `a readable extreme-depth Mystery still prepares materials after disk reload`() throws {
        let context = try PersistenceTestContext()
        var save = SaveTestSupport.makeSave()
        save.labyrinth.ensureMap(seed: save.worldSeed)
        let nodeID = try #require(save.labyrinth.reachableNodeIDs().first)
        let existing = try #require(save.labyrinth.nodes[nodeID])
        save.labyrinth.nodes[nodeID] = LabyrinthNode(
            id: nodeID, type: .mystery, enemyID: nil, depth: Int.max,
            clusterID: existing.clusterID, gridPosition: existing.gridPosition,
            outgoingIDs: existing.outgoingIDs, isCleared: false, isRevealed: true,
        )
        try SaveTestSupport.writeRoot(save, to: context.storeURL())
        let store = try context.makeSaveStore()
        #expect(store.labyrinth.nodes[nodeID]?.depth == Int.max)
        let encounter = EncounterIdentity(location: .labyrinth(nodeID: nodeID), save: store.currentSave)
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        var rng = SeededRandomNumberGenerator(seed: 42)
        var candidate = store.currentSave

        let offers = try MysteryOfferPersistence.prepare(event: event, encounter: encounter, save: &candidate, using: &rng)

        #expect(!offers.isEmpty)
        #expect(offers.contains { offer in
            if case let .material(.gems, quantity) = offer.bonus {
                return quantity > Int.max / 14
            }
            return false
        })
        #expect(store.persistBatch(logging: "Pin extreme-depth Mystery materials") { $0.labyrinth = candidate.labyrinth })
        var reloaded = try context.makeReloadedStore().currentSave
        let reopened = try MysteryOfferPersistence.prepare(event: event, encounter: encounter, save: &reloaded, using: &rng)
        #expect(reopened == offers)
    }
}
