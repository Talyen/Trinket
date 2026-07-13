import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct PlayerRosterStateTests {
    @Test func setLoadoutOverridesDefaultAbilityChoices() throws {
        var roster = PlayerRosterState.initial
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

    @Test func battleConfiguredCombatantFiltersLockedPlayerAbilityTiers() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .block,
            skill: .plateMail,
            ultimate: .sanctifiedPlate
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.battleConfiguredCombatant(knight)

        try #expect(roster.loadout(for: knight).skill?.id == "plate-mail")
        try #expect(configured.abilityLoadout.basic?.id == "block")
        try #expect(configured.abilityLoadout.skill?.id == "plate-mail")
        try #expect(configured.abilityLoadout.ultimate == nil)
        try #expect(configured.abilities.map(\.id) == ["block", "plate-mail"])
    }

    @Test func battleConfiguredCombatantRestoresPlayerAbilityTiersAtUnlockLevels() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .block,
            skill: .plateMail,
            ultimate: .sanctifiedPlate
        )
        roster.setLoadout(customLoadout, for: knight)

        roster.progressions[knight.id] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 220)
        try #expect(roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["block", "plate-mail"])

        roster.progressions[knight.id] = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        try #expect(
            roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["block", "plate-mail", "sanctified-plate"]
        )
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

    @Test func goldMutationRulesRespectBounds() throws {
        var roster = PlayerRosterState.initial
        roster.gold = 25

        roster.grantGold(0)
        roster.grantGold(-5)

        try #expect(roster.gold == 25)
        roster.gold = PlayerRosterState.maxGoldBalance + 1
        #expect(roster.gold == PlayerRosterState.maxGoldBalance)

        roster.gold = PlayerRosterState.maxGoldBalance - 1
        roster.grantGold(50)

        #expect(roster.gold == PlayerRosterState.maxGoldBalance)
    }

    @Test func spendGoldRespectsAffordabilityAndBounds() {
        var roster = PlayerRosterState.initial
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

    @Test func equippedItemResolvesFromInventoryAndLoadout() throws {
        let roster = PlayerRosterState.initial
        let inventory = PlayerInventoryState.initial
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        let weapon = roster.equippedItem(for: .weapon, combatant: knight, inventory: inventory)

        try #expect(weapon?.id == "longsword-basic")
        try #expect(weapon?.baseType.slot == .weapon)
    }

    @Test func equipmentLoadoutEquipAndUnequip() throws {
        let item = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var loadout = EquipmentLoadout()

        loadout.equip(item)
        try #expect(loadout.itemID(for: .weapon) == "wand-basic")

        loadout.unequip(.weapon)
        try #expect(loadout.itemID(for: .weapon) == nil)
    }

    @Test func setEquipmentLoadoutUnequipsItemFromOtherCombatants() throws {
        var roster = PlayerRosterState.initial
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let wand = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))

        var wizardLoadout = roster.equipmentLoadout(for: wizard)
        wizardLoadout.equip(wand)
        roster.setEquipmentLoadout(wizardLoadout, for: wizard)

        var knightLoadout = roster.equipmentLoadout(for: knight)
        knightLoadout.equip(wand)
        roster.setEquipmentLoadout(knightLoadout, for: knight)

        try #expect(roster.equipmentLoadout(for: knight).itemID(for: .weapon) == wand.id)
        try #expect(roster.equipmentLoadout(for: wizard).itemID(for: .weapon) == nil)
    }

    @Test func inventorySlotUnlocksWhenSlotItemExists() throws {
        let weapon = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var inventory = PlayerInventoryState.freshStart

        try #expect(!(inventory.hasItem(for: .weapon)))
        try #expect(!(inventory.hasItem(for: .armor)))

        inventory.items.append(weapon)

        try #expect(inventory.hasItem(for: .weapon))
        try #expect(!(inventory.hasItem(for: .armor)))
    }

    @Test func highestLevelsFilterByRoleAndDefaultToOne() throws {
        var roster = PlayerRosterState.initial
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
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })

        roster.unlockedHeroIDs.formUnion([knight.id, wizard.id])
        roster.progressions[PlayerRosterState.starterHeroID] = CombatantProgression(
            level: 2,
            currentXP: 0,
            requiredXP: 100
        )
        roster.progressions[knight.id] = CombatantProgression(level: 8, currentXP: 0, requiredXP: 100)
        roster.progressions[wizard.id] = CombatantProgression(level: 12, currentXP: 0, requiredXP: 100)

        roster.unlockedCompanionIDs.insert(bear.id)
        roster.progressions[bear.id] = CombatantProgression(level: 5, currentXP: 0, requiredXP: 100)

        let heroIDs = roster.collectionHeroes.map(\.id)
        let companionIDs = roster.collectionCompanions.map(\.id)

        try #expect(Array(heroIDs.prefix(3)) == [wizard.id, knight.id, PlayerRosterState.starterHeroID])
        try #expect(heroIDs.dropFirst(3).allSatisfy { !roster.unlockedHeroIDs.contains($0) })
        try #expect(Array(companionIDs.prefix(2)) == [bear.id, PlayerRosterState.starterCompanionID])
        try #expect(companionIDs.dropFirst(2).allSatisfy { !roster.unlockedCompanionIDs.contains($0) })
    }

    @Test func unlockCombatantsSeedsProgressionAndIsIdempotent() throws {
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
    }

    @Test func unlockIgnoresUnknownAndEnemyIDs() throws {
        var roster = PlayerRosterState.freshStart
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
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        try #expect(inventory.items.count == 1)
        try #expect(inventory.items.first?.id == "chapter-1-stage-1-shortsword-basic")
    }
}
