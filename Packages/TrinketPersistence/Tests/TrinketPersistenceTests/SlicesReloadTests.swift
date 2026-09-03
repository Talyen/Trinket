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
        let firstStore = try context.makeSaveStore()
        let spire = try #require(GameContent.spires.first)
        var spires = firstStore.spires
        spires.highestClearedFloorBySpireID[spire.id.rawValue] = 9999
        firstStore.spires = spires

        let reloaded = try context.makeReloadedStore()

        try #expect(reloaded.spires.highestClearedFloor(for: spire.id.rawValue) == spire.floorCount)
    }

    @Test func `custom ability loadout survives reload`() throws {
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
        firstStore.roster = roster

        let reloaded = try context.makeReloadedStore()

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

        let reloaded = try context.makeReloadedStore()

        let companionLoadout = try #require(reloaded.roster.equipmentLoadouts[bear.id])
        try #expect(companionLoadout.itemID(for: .armor) == nil, "removed companion slot must not survive reload")
        try #expect(
            reloaded.inventory.item(matching: armor.id) != nil,
            "unequipped gear returns to inventory rather than being dropped",
        )
    }

    @Test func `tower floor clear survives reload`() throws {
        let storeURL = context.storeURL()
        let spire = try #require(GameContent.spire(id: .ironVein))
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        var save = SaveTestSupport.makeSave(worldSeed: PlayerSave.testWorldSeed)
        try SaveTestSupport.writeRoot(save, to: storeURL)
        let firstStore = try context.makeReloadedStore()
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

    @Test func `claimed journey XP survives reload`() throws {
        let storeURL = context.storeURL()
        let chapter = try #require(GameContent.chapters.first)
        let stage = try #require(chapter.stages.first)
        let save = SaveTestSupport.makeSave(worldSeed: PlayerSave.testWorldSeed)
        try SaveTestSupport.writeRoot(save, to: storeURL)
        let firstStore = try context.makeReloadedStore()
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
