import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct MysteryEffectApplierTests {
    private func makeSave() -> PlayerSave {
        PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .initial,
            inventory: PlayerInventoryState(items: []),
            homestead: .freshStart
        )
    }

    @Test func applyingGoldMaterialsAndExperienceMutatesSave() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = save.roster.activeCompanion
        let heroProgressionBefore = save.roster.progression(for: hero)
        let companionProgressionBefore = save.roster.progression(for: companion)
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [
                .gainGold(20),
                .gainMaterial(.herbs),
                .gainExperience(10),
            ],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedGold == 20)
        try #expect(result.grantedExperience == 10)
        try #expect(
            result.grantedMaterials
                == [ResourceAmount(.herbs, MysteryEffectApplier.materialQuantity(forLevel: 1))]
        )
        try #expect(save.roster.gold == 20)
        try #expect(
            save.homestead.balance(for: .herbs, roster: save.roster)
                >= MysteryEffectApplier.materialQuantity(forLevel: 1)
        )
        try #expect(result.heroProgressionBefore == heroProgressionBefore)
        try #expect(result.heroProgressionAfter == heroProgressionBefore.addingExperience(10))
        try #expect(result.companionProgressionBefore == companionProgressionBefore)
        try #expect(result.companionProgressionAfter == companionProgressionBefore.addingExperience(10))
        try #expect(save.roster.progression(for: hero) == heroProgressionBefore.addingExperience(10))
        try #expect(save.roster.progression(for: companion) == companionProgressionBefore.addingExperience(10))
    }

    @Test func materialQuantityScalesWithLevel() {
        #expect(MysteryEffectApplier.materialQuantity(forLevel: 1) == 4)
        #expect(MysteryEffectApplier.materialQuantity(forLevel: 50) == 18)
        #expect(
            MysteryEffectApplier.materialQuantity(forLevel: 50)
                > MysteryEffectApplier.materialQuantity(forLevel: 1)
        )
    }

    @Test func generatedItemIncludesGuaranteedAffixAndUsesRolledRarity() throws {
        var save = makeSave()
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 11)

        let result = MysteryEffectApplier.apply(
            [.gainGeneratedItem(baseTypeID: "sapphire_ring", guaranteedAffixIDs: ["manabound"])],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        let item = try #require(result.grantedItems.first)
        try #expect(item.baseType.id == "sapphire_ring")
        try #expect(item.affixes.contains { $0.id == "manabound" })
        try #expect(save.inventory.items.contains(where: { $0.id == item.id }))
        try #expect(item.rarity == .basic || item.rarity == .astral)
    }

    @Test func gainRandomItemAppendsOneInventoryItem() throws {
        var save = makeSave()
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 99)

        let result = MysteryEffectApplier.apply(
            [.gainRandomItem],
            stageID: "chapter-1-stage-2",
            choiceID: "loot-crypt",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedItems.count == 1)
        try #expect(save.inventory.items.count == 1)
    }

    @Test func manaBerryHarvestChoiceAppliesExpectedRewards() throws {
        var save = makeSave()
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let harvest = try #require(event.choices.first { $0.id == "harvest" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 3)

        let result = MysteryEffectApplier.apply(
            harvest.effects,
            stageID: "chapter-1-stage-2",
            choiceID: harvest.id,
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(
            result.grantedMaterials
                .contains(ResourceAmount(.herbs, MysteryEffectApplier.materialQuantity(forLevel: 1)))
        )
        let ring = try #require(result.grantedItems.first)
        try #expect(ring.baseType.id == "sapphire_ring")
        try #expect(ring.affixes.contains { $0.id == "manabound" })
    }

    @Test func unlockCombatantEffectsHandleHeroAndCompanionIdempotently() throws {
        var save = makeFreshSave()
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let first = MysteryEffectApplier.apply(
            [.unlockCombatant("rogue")],
            stageID: "chapter-1-stage-8",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )
        try #expect(first.unlockedCombatantIDs == ["rogue"])
        try #expect(save.roster.isHeroUnlocked("rogue"))

        let second = MysteryEffectApplier.apply(
            [.unlockCombatant("rogue")],
            stageID: "chapter-1-stage-8",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )
        try #expect(second.unlockedCombatantIDs.isEmpty)

        let result = MysteryEffectApplier.apply(
            [.unlockCombatant("bear")],
            stageID: "chapter-1-stage-2",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.unlockedCombatantIDs == ["bear"])
        try #expect(save.roster.isCompanionUnlocked("bear"))
    }

    private func makeFreshSave() -> PlayerSave {
        PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .freshStart,
            inventory: PlayerInventoryState(items: []),
            homestead: .freshStart
        )
    }
}
