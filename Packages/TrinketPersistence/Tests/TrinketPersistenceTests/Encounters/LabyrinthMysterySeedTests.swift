import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct LabyrinthMysterySeedTests {
    @Test func `retained Labyrinth completion grants the map seed loot after a root change`() throws {
        var original = PlayerSave.testSeed
        original.worldSeed = 55
        original.labyrinth.ensureMap(seed: 55)
        let node = try #require(original.labyrinth.nodes.values.first { $0.type == .battle })
        let effects = original.labyrinth.effects(for: node.id)
        let expected = try #require(BattleLootContext(save: original).labyrinth(for: node, effects: effects, encounterLevel: 10))
        let differentSeed = try #require((UInt64(1) ... 32).first { seed in
            let loot = BattleLootContext(save: original, worldSeed: seed).labyrinth(for: node, effects: effects, encounterLevel: 10)
            return loot?.item != expected.item
        })
        var changed = original
        changed.worldSeed = differentSeed

        for useChangedRoot in [false, true] {
            var save = useChangedRoot ? changed : original
            #expect(LabyrinthCompletion.complete(
                nodeID: node.id, hero: save.roster.activeHero, companion: save.roster.activeCompanion,
                rewards: .unsettled(.init(enemyEncounterLevel: 10)), save: &save,
            ) == .completed)
            #expect(save.inventory.item(matching: expected.item.id) == expected.item)
            #expect(save.labyrinth.node(id: node.id)?.isCleared == true)
        }
    }

    @Test @MainActor func `retained Labyrinth mysteries use their map seed across root changes and reload`() throws {
        let context = try PersistenceTestContext()
        var save = PlayerSave.testSeed
        save.labyrinth.ensureMap(seed: 55)
        let node = try #require(save.labyrinth.nodes.values.first { $0.type == .mystery })
        let expected = GameContent.resolveLabyrinthMysteryEvent(
            nodeID: node.id, worldSeed: 55, forcedEventID: nil,
            context: .labyrinth(inventory: save.inventory, corruptionAltarCooldownRemaining: save.corruptionAltarCooldownRemaining),
        )
        for rootSeed in UInt64(1) ... 8 {
            save.worldSeed = rootSeed
            let encounter = EncounterIdentity(location: .labyrinth(nodeID: node.id), save: save)
            #expect(encounter.worldSeed == 55)
            #expect(encounter.mysteryEvent(in: save)?.id == expected.id)
        }
        let store = try context.seedAndReload(save)
        let preview = LabyrinthMysteryPreview(playerSave: store)
        #expect(preview.worldSeed == 55)
        #expect(preview.event(for: node.id)?.id == expected.id)
    }
}
