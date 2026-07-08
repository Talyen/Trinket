import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

@MainActor
struct ActiveBattleConfigurationTests {
    @Test func makeWithoutEquipmentUsesTraitOnlyModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first?.combatant)

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy
        )

        #expect(configuration.hero.modifiers.blockGainedBonus == 1)
        #expect(configuration.pet.modifiers.bleedDurationBonus == 1)
        #expect(configuration.hero.modifiers.damageDealtBonus(for: .physical) == 0)
        #expect(configuration.pet.modifiers.damageDealtBonus(for: .physical) == 0)
        #expect(configuration.hero.combatant.id == knight.id)
        #expect(configuration.pet.combatant.id == wolf.id)
    }

    @Test func makeResolvesEquippedItemModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let item = InventoryItem(
            id: "keen-longsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .basic)]
        )
        var rosterState = PlayerRosterState.initial
        var loadout = EquipmentLoadout()
        loadout.equip(item)
        rosterState.setEquipmentLoadout(loadout, for: knight)

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy,
            roster: rosterState,
            inventory: PlayerInventoryState(items: [item])
        )

        #expect(configuration.hero.modifiers.damageDealtBonus(for: .physical) == 1)
        #expect(configuration.hero.combatant.primaryStats.strength == knight.primaryStats.strength)
    }

    @Test func makeResolvesEnemyTraitModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: skeleton.combatant
        )

        #expect(configuration.enemyModifiers.damageTakenVulnerability(for: .holy) > 0)
        #expect(configuration.enemyModifiers.controlResistancePercent > 0)
    }

    @Test func makePreservesStageMetadata() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battleEnemyID = try #require(stage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: battleEnemyID)?.combatant)
        let itemTemplateID = try #require(stage.rewards.itemTemplateIDs.first)
        let expectedItemName = try #require(
            GameContent.itemTemplate(matching: itemTemplateID)?.displayName
        )

        let configuration = try ActiveBattleConfigurationTestSupport.make(
            stageID: stage.id,
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy,
            stageReward: stage.rewards
        )

        #expect(configuration.stageID == stage.id)
        #expect(configuration.stageReward == stage.rewards)
        #expect(configuration.rewardItemNames == [expectedItemName])
    }

    @Test func resolvedEncounterScalesEnemyToJourneyLevel() throws {
        let stage = try #require(GameContent.chapters[0].stages.first)
        let encounter = try #require(ActiveBattleConfiguration.resolvedEncounter(for: stage))
        let chapter = try #require(GameContent.chapters.first { $0.id == stage.chapterID })
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)

        #expect(encounter.level == expectedLevel)
        #expect(encounter.combatant.id == stage.encounter.battleEnemyID)
    }
}
