import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite
struct PlayerRosterStateTests {
    @Test func setLoadoutOverridesDefaultAbilityChoices() throws {
        var roster = PlayerRosterState.initial
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .bash,
            skill: .smite,
            ultimate: .blessedAegis
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.configuredCombatant(knight)

        try #expect(configured.abilityLoadout.skill?.id == "smite")
        try #expect(configured.abilityLoadout.ultimate?.id == "blessed-aegis")
    }

    @Test func battleConfiguredCombatantFiltersLockedPlayerAbilityTiers() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .shieldBash,
            skill: .spikedShield,
            ultimate: .plateMail
        )

        roster.setLoadout(customLoadout, for: knight)
        let configured = roster.battleConfiguredCombatant(knight)

        try #expect(roster.loadout(for: knight).skill?.id == "spiked-shield")
        try #expect(configured.abilityLoadout.basic?.id == "shield-bash")
        try #expect(configured.abilityLoadout.skill?.id == "spiked-shield")
        try #expect(configured.abilityLoadout.ultimate == nil)
        try #expect(configured.abilities.map(\.id) == ["shield-bash", "spiked-shield"])
    }

    @Test func battleConfiguredCombatantRestoresPlayerAbilityTiersAtUnlockLevels() throws {
        var roster = PlayerRosterState.freshStart
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let customLoadout = AbilityLoadout(
            basic: .shieldBash,
            skill: .spikedShield,
            ultimate: .plateMail
        )
        roster.setLoadout(customLoadout, for: knight)

        roster.progressions[knight.id] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 220)
        try #expect(roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["shield-bash", "spiked-shield"])

        roster.progressions[knight.id] = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        try #expect(
            roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["shield-bash", "spiked-shield", "plate-mail"]
        )
    }

    @Test func battleConfiguredCombatantDoesNotFilterEnemyAbilities() throws {
        let roster = PlayerRosterState.freshStart
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configured = roster.battleConfiguredCombatant(enemy)

        try #expect(configured.abilityLoadout.skill?.tier == .skill)
        try #expect(configured.abilityLoadout.ultimate?.tier == .ultimate)
    }

    @Test func setActiveHeroAndPetUpdatesIDs() throws {
        var roster = PlayerRosterState.initial
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })

        roster.setActiveHero(wizard)
        roster.setActivePet(wolf)

        try #expect(roster.activeHeroID == "wizard")
        try #expect(roster.activePetID == "wolf")
    }

    @Test func setActiveHeroIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })

        roster.setActiveHero(wizard)

        try #expect(roster.activeHeroID == PlayerRosterState.starterHeroID)
    }

    @Test func setActivePetIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })

        roster.setActivePet(wolf)

        try #expect(roster.activePetID == PlayerRosterState.starterPetID)
    }

    @Test func grantGoldIgnoresNonPositiveAmounts() throws {
        var roster = PlayerRosterState.initial
        roster.gold = 25

        roster.grantGold(0)
        roster.grantGold(-5)

        try #expect(roster.gold == 25)
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

    @Test func itemMatchingResolvesTemplateIDForRewardInstances() throws {
        var inventory = PlayerInventoryState(items: [])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        inventory.addRewardItem(from: template, for: GameContent.chapters[0].stages[0])

        _ = try #require(inventory.item(matching: "shortsword-basic"))
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

    @Test func highestHeroLevelWithSingleHero() throws {
        var roster = PlayerRosterState.freshStart
        roster.progressions[PlayerRosterState.starterHeroID] = CombatantProgression(level: 5, currentXP: 0, requiredXP: 100)
        try #expect(roster.highestHeroLevel == 5)
    }

    @Test func highestHeroLevelWithMultipleHeroes() throws {
        var roster = PlayerRosterState.initial
        roster.progressions["knight"] = CombatantProgression(level: 8, currentXP: 0, requiredXP: 100)
        roster.progressions["wizard"] = CombatantProgression(level: 12, currentXP: 0, requiredXP: 100)
        try #expect(roster.highestHeroLevel == 12)
    }

    @Test func highestHeroLevelFallsBackToOne() throws {
        let roster = PlayerRosterState.freshStart
        try #expect(roster.highestHeroLevel == 1)
    }

    @Test func highestPetLevelWithMultiplePets() throws {
        var roster = PlayerRosterState.initial
        roster.progressions["bear"] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 100)
        roster.progressions["wolf"] = CombatantProgression(level: 7, currentXP: 0, requiredXP: 100)
        try #expect(roster.highestPetLevel == 7)
    }

    @Test func highestPetLevelFallsBackToOne() throws {
        let roster = PlayerRosterState.freshStart
        try #expect(roster.highestPetLevel == 1)
    }

    @Test func highestLevelsIgnoresUnrelatedIDs() throws {
        var roster = PlayerRosterState.freshStart
        roster.progressions["bear"] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        try #expect(roster.highestHeroLevel == 1)
        try #expect(roster.highestPetLevel == 15)
    }

    @Test func unlockHeroAddsToRosterAndSeedsProgression() throws {
        var roster = PlayerRosterState.freshStart
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })

        try #expect(roster.unlock(rogue))
        try #expect(roster.isHeroUnlocked("rogue"))
        try #expect(roster.progressions["rogue"] == .initial)
        try #expect(roster.unlock(rogue) == false)
    }

    @Test func unlockPetAddsToRosterAndSeedsProgression() throws {
        var roster = PlayerRosterState.freshStart
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })

        try #expect(roster.unlock(wolf))
        try #expect(roster.isPetUnlocked("wolf"))
        try #expect(roster.progressions["wolf"] == .initial)
        try #expect(roster.unlockPet(id: "wolf") == false)
    }

    @Test func unlockIgnoresUnknownAndEnemyIDs() throws {
        var roster = PlayerRosterState.freshStart
        try #expect(roster.unlockHero(id: "missing-hero") == false)
        try #expect(roster.unlockPet(id: "missing-pet") == false)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        try #expect(roster.unlock(enemy) == false)
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
