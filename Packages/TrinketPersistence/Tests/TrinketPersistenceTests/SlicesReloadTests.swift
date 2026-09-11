import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct SlicesReloadTests {
    @Test @MainActor func `spires floor clamp survives reload`() throws {
        let context = try PersistenceTestContext()
        let firstStore = try context.makeSaveStore()
        let spire = try #require(GameContent.spires.first)
        var spires = firstStore.spires
        spires.highestClearedFloorBySpireID[spire.id.rawValue] = 9999
        #expect(firstStore.persistBatch(logging: "Test setup") { $0.spires = spires })

        let reloaded = try context.makeReloadedStore()

        try #expect(reloaded.spires.highestClearedFloor(for: spire.id.rawValue) == spire.floorCount)
    }

    @Test @MainActor func `custom ability loadout survives reload`() throws {
        let context = try PersistenceTestContext()
        let firstStore = try context.makeSaveStore()
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        var loadout = knight.abilityLoadout
        let thirdChoiceBasic = try #require(knight.abilityChoices.abilities(for: .basic).dropFirst(2).first)
        let fourthChoiceSkill = try #require(knight.abilityChoices.abilities(for: .skill).dropFirst(3).first)
        let thirdChoiceUltimate = try #require(knight.abilityChoices.abilities(for: .ultimate).dropFirst(2).first)
        loadout = loadout.selecting(thirdChoiceBasic)
        loadout = loadout.selecting(fourthChoiceSkill)
        loadout = loadout.selecting(thirdChoiceUltimate)
        var roster = firstStore.roster
        roster.abilityLoadouts["knight"] = loadout
        #expect(firstStore.persistBatch(logging: "Test setup") { $0.roster = roster })

        let reloaded = try context.makeReloadedStore()

        let persistedLoadout = try #require(reloaded.roster.abilityLoadouts["knight"])
        try #expect(persistedLoadout == loadout)
    }

    @Test @MainActor func `companion armor from old save unequips on reload and item survives`() throws {
        let context = try PersistenceTestContext()
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let leatherBase = try #require(GameContent.itemBaseType(matching: "leather_armor"))
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

        let reloaded = try context.seedAndReload(oldSave)

        let companionLoadout = try #require(reloaded.roster.equipmentLoadouts[bear.id])
        try #expect(companionLoadout.itemID(for: .armor) == nil, "removed companion slot must not survive reload")
        try #expect(
            reloaded.inventory.item(matching: armor.id) != nil,
            "unequipped gear returns to inventory rather than being dropped",
        )
    }

    @Test @MainActor func `tower floor clear survives reload`() throws {
        let context = try PersistenceTestContext()
        let spire = try #require(GameContent.spire(id: .ironVein))
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let save = SaveTestSupport.makeSave(worldSeed: PlayerSave.testWorldSeed)
        let firstStore = try context.seedAndReload(save)
        var draft = firstStore.currentSave
        SpireCompletion.complete(
            floor: floor,
            hero: draft.roster.activeHero,
            companion: draft.roster.activeCompanion,
            save: &draft,
        )
        let clearedXP = draft.roster.progression(for: draft.roster.activeHero).currentXP
        try firstStore.performBatchMutation { $0 = draft }

        let reloaded = try context.makeReloadedStore()

        try #expect(reloaded.spires.isFloorCleared(1, spireID: spire.id.rawValue))
        try #expect(reloaded.roster.progression(for: reloaded.roster.activeHero).currentXP == clearedXP)
        try #expect(clearedXP > 0)
    }

    @Test @MainActor func `claimed journey XP survives reload`() throws {
        let context = try PersistenceTestContext()
        let chapter = try #require(GameContent.chapters.first)
        let stage = try #require(chapter.stages.first)
        let save = SaveTestSupport.makeSave(worldSeed: PlayerSave.testWorldSeed)
        let firstStore = try context.seedAndReload(save)
        var draft = firstStore.currentSave
        StageCompletion.complete(
            stage,
            hero: draft.roster.activeHero,
            companion: draft.roster.activeCompanion,
            in: GameContent.chapters,
            save: &draft,
        )
        let heroXP = draft.roster.progression(for: draft.roster.activeHero).currentXP
        try firstStore.performBatchMutation { $0 = draft }

        let reloaded = try context.makeReloadedStore()

        try #expect(reloaded.journey.hasClaimedRewards(for: stage))
        try #expect(reloaded.roster.progression(for: reloaded.roster.activeHero).currentXP == heroXP)
        try #expect(heroXP > 0)
    }
}
