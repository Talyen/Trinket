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
        let startingXP = save.roster.progression(for: hero).experience
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [
                .gainGold(20),
                .gainMaterial(.herbs, 3),
                .gainExperience(10)
            ],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            hero: hero,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedGold == 20)
        try #expect(result.grantedExperience == 10)
        try #expect(result.grantedMaterials == [ResourceAmount(.herbs, 3)])
        try #expect(save.roster.gold == 20)
        try #expect(save.homestead.balance(for: .herbs, roster: save.roster) >= 3)
        try #expect(save.roster.progression(for: hero).experience == startingXP + 10)
    }

    @Test func generatedItemIncludesGuaranteedAffixAndUsesRolledRarity() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 11)

        let result = MysteryEffectApplier.apply(
            [.gainGeneratedItem(baseTypeID: "sapphire_ring", guaranteedAffixIDs: ["manabound"])],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            hero: hero,
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
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 99)

        let result = MysteryEffectApplier.apply(
            [.gainRandomItem],
            stageID: "chapter-1-stage-2",
            choiceID: "loot-crypt",
            hero: hero,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedItems.count == 1)
        try #expect(save.inventory.items.count == 1)
    }

    @Test func chooseItemReturnsCandidatesWithoutGranting() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 5)

        let result = MysteryEffectApplier.apply(
            [.chooseItem],
            stageID: "chapter-1-stage-2",
            choiceID: "search-scrolls",
            hero: hero,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.chooseItemCandidates.count == MysteryEffectApplier.chooseItemCandidateCount)
        try #expect(result.grantedItems.isEmpty)
        try #expect(save.inventory.items.isEmpty)

        let chosen = try #require(result.chooseItemCandidates.first)
        MysteryEffectApplier.grantChosenItem(chosen, save: &save)
        try #expect(save.inventory.items.map(\.id) == [chosen.id])
    }

    @Test func manaBerryHarvestChoiceAppliesExpectedRewards() throws {
        var save = makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let harvest = try #require(event.choices.first { $0.id == "harvest" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 3)

        let result = MysteryEffectApplier.apply(
            harvest.effects,
            stageID: "chapter-1-stage-2",
            choiceID: harvest.id,
            hero: hero,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedMaterials.contains(ResourceAmount(.herbs, 3)))
        let ring = try #require(result.grantedItems.first)
        try #expect(ring.baseType.id == "sapphire_ring")
        try #expect(ring.affixes.contains { $0.id == "manabound" })
    }
}
