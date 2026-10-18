import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct RosterEditPersistenceTests {
    #if DEBUG
    @Test @MainActor func `failed combatant edits preserve the roster and retry persists`() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "CombatantEdits")
        defer { SaveTestSupport.removeTempDirectory(directory) }
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        let hero = try #require(GameContent.hero(matching: "knight"))
        let item = try SaveTestSupport.makeGeneratedItem(baseID: "longsword", rarity: .basic)
        let node = try #require(CombatantTalentCatalog.configIfAvailable(for: hero.id)?.trees.first?.nodes.first)
        try playerSave.performFixtureMutation { save in
            save.roster = .testSeed
            save.roster.progressions[hero.id] = .at(level: 2)
            save.roster.setEquipmentLoadout(.init(), for: hero)
            save.roster.setLoadout(save.roster.loadout(for: hero).selecting(.bash), for: hero)
            save.roster.setUnlockedTalents([node.id], for: hero.id)
            save.inventory.items = [item]
        }
        let commands: [CombatantLoadoutEdit] = [
            .selectAbility(abilityID: Ability.slash.id), .equipItem(itemID: item.id, slot: .weapon),
            .unequipItem(.weapon), .resetTalents,
        ]
        for command in commands {
            let before = playerSave.roster
            playerSave.forcesNextSaveFailure = true
            #expect(playerSave.editCombatant(command, for: hero.id) == .persistenceFailed)
            #expect(playerSave.roster == before)
            #expect(playerSave.editCombatant(command, for: hero.id) == .committed)
            let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: directory)
            #expect(reloaded.roster == playerSave.roster)
            switch command {
            case .selectAbility:
                #expect(reloaded.roster.loadout(for: hero).basic?.id == Ability.slash.id)
            case .equipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == item.id)
            case .unequipItem:
                #expect(reloaded.roster.equipmentLoadout(for: hero).itemID(for: .weapon) == nil)
            case .resetTalents:
                #expect(reloaded.roster.unlockedTalents(for: hero.id).isEmpty)
            }
        }
    }
    #endif

    @Test @MainActor func `stale and inaccessible roster intents reject before writing and preserve reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let knight = try #require(GameContent.hero(matching: "knight"))
        let premium = try #require(GameContent.hero(matching: "druid"))
        let tree = try #require(CombatantTalentCatalog.configIfAvailable(for: premium.id)?.trees.first)
        let node = try #require(tree.nodes.first)
        try store.performFixtureMutation { save in
            _ = save.roster.unlock(knight)
            _ = save.roster.unlock(premium)
            save.roster.progressions[premium.id] = .at(level: 4)
        }
        let before = store.currentSave
        #if DEBUG
        // Rejections must not reach storage or consume the next write failure.
        store.forcesNextSaveFailure = true
        #endif
        #expect(store.editCombatant(.selectAbility(abilityID: Ability.slash.id), for: "ranger") == .unavailable)
        #expect(store.editCombatant(.equipItem(itemID: "salvaged-item", slot: .weapon), for: knight.id) == .unavailable)
        #expect(store.selectParty(heroID: knight.id, companionID: "missing-companion") == .unavailable)
        #expect(store.unlockTalent(nodeID: node.id, treeID: tree.id, for: premium.id) == .unavailable)
        #expect(store.currentSave == before)
        store.contentAccess = .fullGame
        // Removing the recruit while an intent is retained must also revoke permission.
        #if DEBUG
        #expect(store.forcesNextSaveFailure)
        store.forcesNextSaveFailure = false
        #endif
        try store.performFixtureMutation { save in
            save.roster.unlockedHeroIDs.remove(premium.id)
        }
        let withoutRecruit = store.currentSave
        #expect(store.unlockTalent(nodeID: node.id, treeID: tree.id, for: premium.id) == .unavailable)
        #expect(store.editCombatant(.resetTalents, for: premium.id) == .unavailable)
        #expect(store.currentSave == withoutRecruit)
        #expect(store.roster.activeHeroID == before.roster.activeHeroID)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster == withoutRecruit.roster)
    }
}
