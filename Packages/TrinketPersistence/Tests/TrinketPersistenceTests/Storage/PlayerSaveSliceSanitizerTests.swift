import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveSliceSanitizerTests {
    @Test func `inventory repair precedes equipment repair`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == PlayerRosterState.starterHeroID })
        let trinketBase = try #require(GameContent.itemBaseTypes.first { $0.slot == .trinket })
        let kept = InventoryItem(
            id: "kept-trinket",
            templateID: "shared-trinket",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Test Ring",
            affixes: [],
        )
        let dropped = InventoryItem(
            id: "dropped-trinket",
            templateID: "shared-trinket",
            baseType: trinketBase,
            rarity: .basic,
            displayName: "Test Ring",
            affixes: [],
        )
        var save = PlayerSave.fresh
        save.inventory = PlayerInventoryState(items: [kept, dropped])
        save.roster.equipmentLoadouts[knight.id] = EquipmentLoadout(itemIDsBySlot: [.trinket: dropped.id])

        let sanitized = PlayerSaveSanitizer.sanitize(save, changedSlices: .inventory)

        #expect(sanitized.inventory.items.map(\.id) == [kept.id])
        #expect(sanitized.roster.equipmentLoadout(for: knight).itemID(for: .trinket) == nil)
    }

    @Test(arguments: [PlayerSaveSlice.inventory, .roster])
    func `inventory and roster repair leave labyrinth damage for its own slice`(_ slice: PlayerSaveSlice) throws {
        var save = PlayerSave.fresh
        save.labyrinth.ensureMap(seed: 4)
        let nodeID = try #require(save.labyrinth.nodes.keys.min())
        save.labyrinth.nodes[nodeID]?.outgoingIDs.append("missing-node")
        save.roster.unlockedHeroIDs.insert("missing-hero")

        let scoped = PlayerSaveSanitizer.sanitize(save, changedSlices: slice)
        let labyrinthRepaired = PlayerSaveSanitizer.sanitize(scoped, changedSlices: .labyrinth)

        #expect(!scoped.roster.unlockedHeroIDs.contains("missing-hero"))
        #expect(scoped.labyrinth == save.labyrinth)
        #expect(labyrinthRepaired.labyrinth.nodes[nodeID]?.outgoingIDs.contains("missing-node") == false)
    }

    @Test func `homestead candidate repairs materials without pinning labyrinth seed`() throws {
        var snapshot = PlayerSave.fresh
        snapshot.labyrinth.worldSeed = 0
        var proposed = snapshot
        proposed.homestead.resources[.wood] = 4
        proposed.homestead.resources[.stone] = -3

        let (candidate, _) = try PlayerSaveSlice.prepareCandidate(from: snapshot, candidate: proposed)

        #expect(candidate.homestead.resources[.wood] == 4)
        #expect(candidate.homestead.resources[.stone] == 0)
        #expect(candidate.labyrinth == snapshot.labyrinth)
    }

    @Test @MainActor func `homestead mutation preserves labyrinth across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let labyrinth = store.currentSave.labyrinth
        let wood = (store.homestead.resources[.wood] ?? 0) + 1

        try store.performBatchMutation { $0.homestead.resources[.wood] = wood }

        #expect(store.currentSave.labyrinth == labyrinth)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.currentSave.labyrinth == labyrinth)
        #expect(reloaded.homestead.resources[.wood] == wood)
    }
}
