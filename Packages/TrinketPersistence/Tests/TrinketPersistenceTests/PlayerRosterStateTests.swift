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

        #expect(configured.abilityLoadout.skill?.id == "smite")
        #expect(configured.abilityLoadout.ultimate?.id == "blessed-aegis")
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

        #expect(roster.loadout(for: knight).skill?.id == "spiked-shield")
        #expect(configured.abilityLoadout.basic?.id == "shield-bash")
        #expect(configured.abilityLoadout.skill?.id == "spiked-shield")
        #expect(configured.abilityLoadout.ultimate == nil)
        #expect(configured.abilities.map(\.id) == ["shield-bash", "spiked-shield"])
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
        #expect(roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["shield-bash", "spiked-shield"])

        roster.progressions[knight.id] = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        #expect(
            roster.battleConfiguredCombatant(knight).abilities.map(\.id) == ["shield-bash", "spiked-shield", "plate-mail"]
        )
    }

    @Test func battleConfiguredCombatantDoesNotFilterEnemyAbilities() throws {
        let roster = PlayerRosterState.freshStart
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configured = roster.battleConfiguredCombatant(enemy)

        #expect(configured.abilityLoadout.skill?.tier == .skill)
        #expect(configured.abilityLoadout.ultimate?.tier == .ultimate)
    }

    @Test func setActiveHeroAndPetUpdatesIDs() throws {
        var roster = PlayerRosterState.initial
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })

        roster.setActiveHero(wizard)
        roster.setActivePet(wolf)

        #expect(roster.activeHeroID == "wizard")
        #expect(roster.activePetID == "wolf")
    }

    @Test func setActiveHeroIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })

        roster.setActiveHero(wizard)

        #expect(roster.activeHeroID == PlayerRosterState.starterHeroID)
    }

    @Test func setActivePetIgnoresLockedCombatantOnFreshStart() throws {
        var roster = PlayerRosterState.freshStart
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })

        roster.setActivePet(wolf)

        #expect(roster.activePetID == PlayerRosterState.starterPetID)
    }

    @Test func grantGoldIgnoresNonPositiveAmounts() {
        var roster = PlayerRosterState.initial
        roster.gold = 25

        roster.grantGold(0)
        roster.grantGold(-5)

        #expect(roster.gold == 25)
    }

    @Test func equippedItemResolvesFromInventoryAndLoadout() throws {
        let roster = PlayerRosterState.initial
        let inventory = PlayerInventoryState.initial
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        let weapon = roster.equippedItem(for: .weapon, combatant: knight, inventory: inventory)

        #expect(weapon?.id == "longsword-basic")
        #expect(weapon?.baseType.slot == .weapon)
    }

    @Test func equipmentLoadoutEquipAndUnequip() throws {
        let item = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var loadout = EquipmentLoadout()

        loadout.equip(item)
        #expect(loadout.itemID(for: .weapon) == "wand-basic")

        loadout.unequip(.weapon)
        #expect(loadout.itemID(for: .weapon) == nil)
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

        #expect(roster.equipmentLoadout(for: knight).itemID(for: .weapon) == wand.id)
        #expect(roster.equipmentLoadout(for: wizard).itemID(for: .weapon) == nil)
    }

    @Test func inventorySlotUnlocksWhenSlotItemExists() throws {
        let weapon = try #require(PlayerInventoryState.initial.item(matching: "wand-basic"))
        var inventory = PlayerInventoryState.freshStart

        #expect(!(inventory.hasItem(for: .weapon)))
        #expect(!(inventory.hasItem(for: .armor)))

        inventory.items.append(weapon)

        #expect(inventory.hasItem(for: .weapon))
        #expect(!(inventory.hasItem(for: .armor)))
    }

    @Test func highestHeroLevelWithSingleHero() {
        var roster = PlayerRosterState.freshStart
        roster.progressions[PlayerRosterState.starterHeroID] = CombatantProgression(level: 5, currentXP: 0, requiredXP: 100)
        #expect(roster.highestHeroLevel == 5)
    }

    @Test func highestHeroLevelWithMultipleHeroes() {
        var roster = PlayerRosterState.initial
        roster.progressions["knight"] = CombatantProgression(level: 8, currentXP: 0, requiredXP: 100)
        roster.progressions["wizard"] = CombatantProgression(level: 12, currentXP: 0, requiredXP: 100)
        #expect(roster.highestHeroLevel == 12)
    }

    @Test func highestHeroLevelFallsBackToOne() {
        let roster = PlayerRosterState.freshStart
        #expect(roster.highestHeroLevel == 1)
    }

    @Test func highestPetLevelWithMultiplePets() {
        var roster = PlayerRosterState.initial
        roster.progressions["bear"] = CombatantProgression(level: 3, currentXP: 0, requiredXP: 100)
        roster.progressions["wolf"] = CombatantProgression(level: 7, currentXP: 0, requiredXP: 100)
        #expect(roster.highestPetLevel == 7)
    }

    @Test func highestPetLevelFallsBackToOne() {
        let roster = PlayerRosterState.freshStart
        #expect(roster.highestPetLevel == 1)
    }

    @Test func highestLevelsIgnoresUnrelatedIDs() {
        var roster = PlayerRosterState.freshStart
        roster.progressions["bear"] = CombatantProgression(level: 15, currentXP: 0, requiredXP: 100)
        #expect(roster.highestHeroLevel == 1)
        #expect(roster.highestPetLevel == 15)
    }

    @Test func addRewardItemIgnoresDuplicateID() throws {
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let stage = GameContent.chapters[0].stages[0]
        var inventory = PlayerInventoryState.freshStart
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
        inventory.addRewardItem(from: template, for: stage, using: &randomNumberGenerator)

        #expect(inventory.items.count == 1)
        #expect(inventory.items.first?.id == "chapter-1-stage-1-shortsword-basic")
    }
}
