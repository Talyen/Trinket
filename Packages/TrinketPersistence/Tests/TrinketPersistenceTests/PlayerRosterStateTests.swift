import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct PlayerRosterStateTests {
    @Test func setLoadoutOverridesDefaultAbilityChoices() throws {
        var roster = PlayerRosterState.testSeed
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .bash,
            skill: .smite,
            ultimate: .avatarOfJustice
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.configuredCombatant(knight)

        try #expect(configured.abilityLoadout.skill?.id == "smite")
        try #expect(configured.abilityLoadout.ultimate?.id == "avatar-of-justice")
    }

    @Test func battleConfiguredCombatantIncludesAllPlayerAbilityTiersByDefault() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .block,
            skill: .sunder,
            ultimate: .moltenBulwark
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.battleConfiguredCombatant(knight)

        try #expect(roster.loadout(for: knight).skill?.id == "sunder")
        try #expect(configured.abilityLoadout.basic?.id == "block")
        try #expect(configured.abilityLoadout.skill?.id == "sunder")
        try #expect(configured.abilityLoadout.ultimate?.id == "molten-bulwark")
        try #expect(configured.abilities.map(\.id) == ["block", "sunder", "molten-bulwark"])
    }

    @Test func battleConfiguredCombatantDoesNotFilterEnemyAbilities() throws {
        let roster = PlayerRosterState.freshStart
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configured = roster.battleConfiguredCombatant(enemy)

        try #expect(configured.abilityLoadout.skill?.tier == .skill)
        try #expect(configured.abilityLoadout.ultimate?.tier == .ultimate)
    }

    @Test func setActiveCombatantsIgnoresLockedEntriesOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })

        roster.setActiveHero(wizard)
        try #expect(roster.activeHeroID == PlayerRosterState.starterHeroID)
        roster.setActiveCompanion(bear)
        try #expect(roster.activeCompanionID == PlayerRosterState.starterCompanionID)
    }

    @Test func goldMutationAndSpendRespectBounds() throws {
        var roster = PlayerRosterState.testSeed
        roster.gold = 25

        roster.grantGold(0)
        roster.grantGold(-5)

        try #expect(roster.gold == 25)
        roster.gold = PlayerRosterState.maxGoldBalance + 1
        #expect(roster.gold == PlayerRosterState.maxGoldBalance)

        roster.gold = PlayerRosterState.maxGoldBalance - 1
        roster.grantGold(50)

        #expect(roster.gold == PlayerRosterState.maxGoldBalance)

        roster.gold = 40
        let spent = roster.spendGold(28)
        #expect(spent)
        #expect(roster.gold == 12)

        roster.gold = 10
        let overspend = roster.spendGold(11)
        let zeroSpend = roster.spendGold(0)
        let negativeSpend = roster.spendGold(-3)
        #expect(!overspend)
        #expect(!zeroSpend)
        #expect(!negativeSpend)
        #expect(roster.gold == 10)
    }

    @Test func signedGoldDeltaCannotReduceBalanceBelowZero() {
        var save = PlayerSave.fresh
        save.roster.gold = 2

        let applied = save.applyGoldDelta(-3)

        #expect(applied == -2)
        #expect(save.roster.gold == 0)
    }

    @Test func equippedItemResolvesFromInventoryAndLoadout() throws {
        let roster = PlayerRosterState.testSeed
        let inventory = PlayerInventoryState.testSeed
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        let weapon = roster.equippedItem(for: .weapon, combatant: knight, inventory: inventory)

        try #expect(weapon?.id == "longsword-basic")
        try #expect(weapon?.baseType.slot == .weapon)
    }

    @Test func equipmentLoadoutEquipAndUnequip() throws {
        let item = try #require(PlayerInventoryState.testSeed.item(matching: "wand-basic"))
        var loadout = EquipmentLoadout()

        loadout.equip(item, inventory: [item])
        try #expect(loadout.itemID(for: .weapon) == "wand-basic")

        loadout.unequip(.weapon)
        try #expect(loadout.itemID(for: .weapon) == nil)
    }

    @Test func legacyTrinketSlotsMigrateToAccessorySlotsAndUnequipRemovedSlots() throws {
        let accessoryBase = try #require(GameContent.itemBaseTypes.first { $0.id == "ruby_ring" })
        let items = [
            InventoryItem(id: "hero-primary", baseType: accessoryBase, rarity: .basic, displayName: "Ruby Ring", affixes: []),
            InventoryItem(id: "hero-secondary", baseType: accessoryBase, rarity: .basic, displayName: "Ruby Ring", affixes: []),
            InventoryItem(id: "hero-tertiary", baseType: accessoryBase, rarity: .basic, displayName: "Ruby Ring", affixes: []),
            InventoryItem(id: "companion-primary", baseType: accessoryBase, rarity: .basic, displayName: "Ruby Ring", affixes: []),
            InventoryItem(id: "companion-secondary", baseType: accessoryBase, rarity: .basic, displayName: "Ruby Ring", affixes: []),
        ]
        let heroLoadout = EquipmentLoadoutModel(combatantID: "knight")
        heroLoadout.slots = [
            EquipmentSlotModel(slotID: "Trinket", itemID: "hero-primary"),
            EquipmentSlotModel(slotID: "Secondary Trinket", itemID: "hero-secondary"),
            EquipmentSlotModel(slotID: "Tertiary Trinket", itemID: "hero-tertiary"),
        ]
        let companionLoadout = EquipmentLoadoutModel(combatantID: "bear")
        companionLoadout.slots = [
            EquipmentSlotModel(slotID: "Trinket", itemID: "companion-primary"),
            EquipmentSlotModel(slotID: "Secondary Trinket", itemID: "companion-secondary"),
        ]
        let model = RosterModel()
        model.equipmentLoadouts = [heroLoadout, companionLoadout]

        let roster = model.toPlayerRosterState(
            inventory: PlayerInventoryState(items: items),
            schemaVersion: 13
        )
        let hero = try #require(roster.equipmentLoadouts["knight"])
        let companion = try #require(roster.equipmentLoadouts["bear"])

        try #expect(hero.itemID(for: .accessory) == "hero-primary")
        try #expect(hero.itemID(for: .secondaryAccessory) == "hero-secondary")
        try #expect(!hero.itemIDsBySlot.values.contains("hero-tertiary"))
        try #expect(companion.itemID(for: .accessory) == "companion-primary")
        try #expect(!companion.itemIDsBySlot.values.contains("companion-secondary"))
    }

    @Test func setEquipmentLoadoutEnforcesUniqueItemOwnership() throws {
        var roster = PlayerRosterState.testSeed
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let wand = try #require(PlayerInventoryState.testSeed.item(matching: "wand-basic"))

        var wizardLoadout = roster.equipmentLoadout(for: wizard)
        wizardLoadout.equip(wand, inventory: [wand])
        roster.setEquipmentLoadout(wizardLoadout, for: wizard)

        var knightLoadout = roster.equipmentLoadout(for: knight)
        knightLoadout.equip(wand, inventory: [wand])
        roster.setEquipmentLoadout(knightLoadout, for: knight)

        try #expect(roster.equipmentLoadout(for: knight).itemID(for: .weapon) == wand.id)
        try #expect(roster.equipmentLoadout(for: wizard).itemID(for: .weapon) == nil)

        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let duplicateLoadout = EquipmentLoadout(itemIDsBySlot: [
            .accessory: "ring-a",
            .trinket: "ring-a",
        ])
        roster.setEquipmentLoadout(duplicateLoadout, for: bear)
        let stored = roster.equipmentLoadout(for: bear)
        try #expect(stored.itemID(for: .accessory) == "ring-a")
        try #expect(stored.itemID(for: .trinket) == nil)
    }

    @Test func highestLevelsFilterByRoleAndDefaultToOne() throws {
        var roster = PlayerRosterState.testSeed
        roster.progressions["knight"] = CombatantProgression(level: 8, currentXP: 0, requiredXP: 100)
        roster.progressions["wizard"] = CombatantProgression(level: 12, currentXP: 0, requiredXP: 100)
        roster.progressions["bear"] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 100)
        roster.progressions["wolf"] = CombatantProgression(level: 7, currentXP: 0, requiredXP: 100)
        try #expect(roster.highestHeroLevel == 12)
        try #expect(roster.highestCompanionLevel == 7)

        var freshRoster = PlayerRosterState.freshStart
        freshRoster.progressions["wolf"] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        try #expect(freshRoster.highestHeroLevel == 1)
        try #expect(freshRoster.highestCompanionLevel == 15)
    }

    @Test func collectionCombatantsPlaceUnlockedEntriesFirstAndSortThemByLevel() throws {
        var roster = PlayerRosterState.freshStart
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })

        roster.unlockedHeroIDs.formUnion([ranger.id, wizard.id])
        roster.progressions[PlayerRosterState.starterHeroID] = CombatantProgression(
            level: 2,
            currentXP: 0,
            requiredXP: 100
        )
        roster.progressions[ranger.id] = CombatantProgression(level: 8, currentXP: 0, requiredXP: 100)
        roster.progressions[wizard.id] = CombatantProgression(level: 12, currentXP: 0, requiredXP: 100)

        roster.unlockedCompanionIDs.insert(bear.id)
        roster.progressions[bear.id] = CombatantProgression(level: 5, currentXP: 0, requiredXP: 100)

        let heroIDs = roster.collectionHeroes.map(\.id)
        let companionIDs = roster.collectionCompanions.map(\.id)

        try #expect(Array(heroIDs.prefix(3)) == [wizard.id, ranger.id, PlayerRosterState.starterHeroID])
        try #expect(heroIDs.dropFirst(3).allSatisfy { !roster.unlockedHeroIDs.contains($0) })
        try #expect(Array(companionIDs.prefix(2)) == [bear.id, PlayerRosterState.starterCompanionID])
        try #expect(companionIDs.dropFirst(2).allSatisfy { !roster.unlockedCompanionIDs.contains($0) })
    }

    @Test func unlockCombatantsSeedsProgressionAndIgnoresInvalidIDs() throws {
        var roster = PlayerRosterState.freshStart
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })

        let unlocked = roster.unlock(rogue)
        try #expect(unlocked)
        try #expect(roster.isHeroUnlocked("rogue"))
        try #expect(roster.progressions["rogue"] == .initial)
        let unlockedAgain = roster.unlock(rogue)
        try #expect(unlockedAgain == false)
        try #expect(roster.unlock(bear))
        try #expect(roster.isCompanionUnlocked("bear"))
        try #expect(roster.progressions["bear"] == .initial)
        let companionUnlockedAgain = roster.unlockCompanion(id: "bear")
        try #expect(companionUnlockedAgain == false)

        let missingHero = roster.unlockHero(id: "missing-hero")
        let missingCompanion = roster.unlockCompanion(id: "missing-companion")
        try #expect(missingHero == false)
        try #expect(missingCompanion == false)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let unlockedEnemy = roster.unlock(enemy)
        try #expect(unlockedEnemy == false)
    }

    @Test func unlockAllCombatantsGrantsCatalogAtRequestedLevel() throws {
        var roster = PlayerRosterState.freshStart
        roster.unlockAllCombatants(atLevel: 20)

        try #expect(roster.unlockedHeroIDs == Set(GameContent.heroes.map(\.id)))
        try #expect(roster.unlockedCompanionIDs == Set(GameContent.companions.map(\.id)))
        for hero in GameContent.heroes {
            try #expect(roster.progression(for: hero) == CombatantProgression.at(level: 20))
        }
        for companion in GameContent.companions {
            try #expect(roster.progression(for: companion) == CombatantProgression.at(level: 20))
        }
        try #expect(roster.highestHeroLevel == 20)
        try #expect(roster.highestCompanionLevel == 20)
    }

    @Test func addRewardItemIgnoresDuplicateID() throws {
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]
        var inventory = PlayerInventoryState.freshStart

        inventory.addRewardItem(from: template, for: stage)
        inventory.addRewardItem(from: template, for: stage)

        try #expect(inventory.items.count == 1)
        try #expect(inventory.items.first?.id == "chapter-1-stage-1-shortsword-basic")
    }

    @Test func unlockTalentRespectsPointsAndRowGates() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let tree = try #require(CombatantTalentCatalog.config(for: knight.id).trees.first)
        let row1A = try #require(tree.nodes(forRow: 1).first)
        let row1B = try #require(tree.nodes(forRow: 1).last)
        let row2 = try #require(tree.nodes(forRow: 2).first)

        #expect(roster.availableTalentPoints(for: knight.id) == 0)
        let refusedAtLevel1 = roster.unlockTalent(node: row1A, inTree: tree, for: knight.id)
        #expect(!refusedAtLevel1)

        roster.progressions[knight.id] = .at(level: 2)
        #expect(roster.availableTalentPoints(for: knight.id) == 1)
        let unlockedRow1A = roster.unlockTalent(node: row1A, inTree: tree, for: knight.id)
        #expect(unlockedRow1A)
        #expect(roster.unlockedTalents(for: knight.id) == Set([row1A.id]))
        #expect(roster.availableTalentPoints(for: knight.id) == 0)
        let refusedDuplicate = roster.unlockTalent(node: row1A, inTree: tree, for: knight.id)
        let refusedRow2Early = roster.unlockTalent(node: row2, inTree: tree, for: knight.id)
        #expect(!refusedDuplicate)
        #expect(!refusedRow2Early)

        roster.progressions[knight.id] = .at(level: 6)
        #expect(roster.availableTalentPoints(for: knight.id) == 2)
        let refusedRow2UntilRow1Complete = roster.unlockTalent(node: row2, inTree: tree, for: knight.id)
        #expect(!refusedRow2UntilRow1Complete)
        let unlockedRow1B = roster.unlockTalent(node: row1B, inTree: tree, for: knight.id)
        let unlockedRow2 = roster.unlockTalent(node: row2, inTree: tree, for: knight.id)
        #expect(unlockedRow1B)
        #expect(unlockedRow2)
        #expect(roster.unlockedTalents(for: knight.id) == Set([row1A.id, row1B.id, row2.id]))
        #expect(roster.availableTalentPoints(for: knight.id) == 0)
    }
}
