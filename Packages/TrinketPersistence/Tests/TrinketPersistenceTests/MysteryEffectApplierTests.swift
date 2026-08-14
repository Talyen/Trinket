import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct MysteryEffectApplierTests {
    @Test func applyingGoldMaterialsAndExperienceMutatesSave() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = save.roster.activeCompanion
        let heroProgressionBefore = save.roster.progression(for: hero)
        let companionProgressionBefore = save.roster.progression(for: companion)
        // Pinned for the seeded fresh roster (knight/wolf at level 2, hero
        // highest level 3): equal-level award 155/1.5=103 with hero catch-up
        // round(103*1.5903)=164; both below the 3x-requiredXP cap.
        let expectedHeroXP = 164
        let expectedCompanionXP = 103
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [
                .gainGold(20),
                .gainMaterial(.herbs),
                .gainExperience,
            ],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedGold == 20)
        try #expect(result.heroGrantedExperience == expectedHeroXP)
        try #expect(result.companionGrantedExperience == expectedCompanionXP)
        try #expect(result.hasGrantedExperience)
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
        try #expect(result.heroProgressionAfter == heroProgressionBefore.addingExperience(expectedHeroXP))
        try #expect(result.companionProgressionBefore == companionProgressionBefore)
        try #expect(
            result.companionProgressionAfter
                == companionProgressionBefore.addingExperience(expectedCompanionXP)
        )
        try #expect(
            save.roster.progression(for: hero) == heroProgressionBefore.addingExperience(expectedHeroXP)
        )
        try #expect(
            save.roster.progression(for: companion)
                == companionProgressionBefore.addingExperience(expectedCompanionXP)
        )
    }

    @Test func gainExperienceScalesPerRecipientLevel() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = save.roster.activeCompanion
        save.roster.progressions[hero.id] = .at(level: 20)
        save.roster.progressions[companion.id] = .at(level: 5)
        let heroBefore = save.roster.progression(for: hero)
        let companionBefore = save.roster.progression(for: companion)
        // Pinned: level-20 equal award 2855 / 2.5 = 1142; level-5 award
        // 380 / 1.5 = 253. Both stay below the 3x-requiredXP cap.
        let expectedHeroXP = 1142
        let expectedCompanionXP = 253
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [.gainExperience],
            stageID: "chapter-1-stage-2",
            choiceID: "study",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.heroGrantedExperience == expectedHeroXP)
        try #expect(result.companionGrantedExperience == expectedCompanionXP)
        try #expect(expectedHeroXP != expectedCompanionXP)
        try #expect(result.heroProgressionAfter == heroBefore.addingExperience(expectedHeroXP))
        try #expect(result.companionProgressionAfter == companionBefore.addingExperience(expectedCompanionXP))
    }

    @Test func grantExperienceCapsAtThreeTimesRequiredXP() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        save.roster.progressions[hero.id] = .at(level: 1)
        let before = save.roster.progression(for: hero)
        let ceiling = before.requiredXP * ExperienceScaling.maxGrantLevelsEquivalent

        let granted = save.roster.grantExperience(10000, to: hero)

        try #expect(granted == ceiling)
        try #expect(save.roster.progression(for: hero) == before.addingExperience(ceiling))
        try #expect(save.roster.progression(for: hero).level > before.level)
        try #expect(save.roster.progression(for: hero).level < before.level + 10)
    }

    @Test func rewardResultReportsOnlyAmountsAcceptedByWallets() throws {
        var save = SaveTestSupport.makeSave()
        save.roster.gold = 995
        save.homestead = PlayerHomesteadState(
            resources: [.herbs: 997],
            nodeTiers: [:],
            pendingProduction: [.gold: 1, .herbs: 1],
            lastProductionAt: Date()
        )
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [.gainGold(10), .gainMaterial(.herbs)],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator
        )

        try #expect(result.grantedGold == 3)
        try #expect(result.grantedMaterials == [ResourceAmount(.herbs, 4)])
        try #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        try #expect(save.homestead.resources[.herbs] == 1001)
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
        var save = SaveTestSupport.makeSave()
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
        var save = SaveTestSupport.makeSave()
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

    @Test func mysteryTrinketsRespectStrongChoiceMappings() throws {
        var mappedTrinketIDs = Set<String>()
        for seed in UInt64(1) ... 300 {
            var save = SaveTestSupport.makeSave()
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let result = MysteryEffectApplier.apply(
                [.gainRandomItem],
                stageID: "chapter-2-stage-2",
                choiceID: "loot-crypt",
                encounterLevel: 6,
                save: &save,
                using: &randomNumberGenerator
            )
            mappedTrinketIDs.formUnion(result.grantedItems.filter(\.isTrinket).map(\.templateID))
        }
        try #expect(!mappedTrinketIDs.isEmpty)
        try #expect(mappedTrinketIDs.isSubset(of: ["bone_charm", "sin_eaters_lantern"]))

        for seed in UInt64(1) ... 300 {
            var save = SaveTestSupport.makeSave()
            var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let result = MysteryEffectApplier.apply(
                [.gainRandomItem],
                stageID: "chapter-2-stage-2",
                choiceID: "unmapped-choice",
                encounterLevel: 6,
                save: &save,
                using: &randomNumberGenerator
            )
            try #expect(!result.grantedItems.contains(where: \.isTrinket))
        }
    }

    @Test func manaBerryHarvestChoiceAppliesExpectedRewards() throws {
        var save = SaveTestSupport.makeSave()
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
        var save = SaveTestSupport.makeSave(roster: .freshStart)
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
}
