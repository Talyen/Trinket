import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class SlicesReloadTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `spires floor clamp survives reload`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let spire = try #require(GameContent.spires.first)
        var spires = firstStore.spires
        spires.highestClearedFloorBySpireID[spire.id.rawValue] = 9999
        firstStore.spires = spires

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(reloaded.spires.highestClearedFloor(for: spire.id.rawValue) == spire.floorCount)
    }

    @Test func `custom ability loadout survives reload`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var loadout = knight.abilityLoadout
        let alternateSkill = try #require(knight.abilityChoices.abilities(for: .skill).dropFirst().first)
        loadout = loadout.selecting(alternateSkill)
        var roster = firstStore.roster
        roster.abilityLoadouts["knight"] = loadout
        firstStore.roster = roster

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        let persistedLoadout = try #require(reloaded.roster.abilityLoadouts["knight"])
        try #expect(persistedLoadout == loadout)
    }

    @Test func `companion armor from old save unequips on reload and item survives`() throws {
        let storeURL = context.storeURL()
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let leatherBase = try #require(GameContent.itemBaseTypes.first { $0.id == "leather_armor" })
        let armor = InventoryItem(
            id: "companion-armor",
            baseType: leatherBase,
            rarity: .basic,
            displayName: "Leather Armor",
            affixes: [],
        )
        var oldSave = PlayerSave.testSeed
        oldSave.inventory.appendUniqueItem(armor)
        oldSave.roster.equipmentLoadouts[bear.id] = EquipmentLoadout(itemIDsBySlot: [.armor: armor.id])

        try SaveTestSupport.writeRoot(oldSave, to: storeURL)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        let companionLoadout = try #require(reloaded.roster.equipmentLoadouts[bear.id])
        try #expect(companionLoadout.itemID(for: .armor) == nil, "removed companion slot must not survive reload")
        try #expect(
            reloaded.inventory.item(matching: armor.id) != nil,
            "unequipped gear returns to inventory rather than being dropped",
        )
    }
}
