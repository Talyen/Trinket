import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct MysteryEffectApplierTests {
    @Test func `applying gold materials and experience mutates save`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = save.roster.activeCompanion
        let heroProgressionBefore = save.roster.progression(for: hero)
        let companionProgressionBefore = save.roster.progression(for: companion)
        let expectedHeroXP = 7
        let expectedCompanionXP = 7
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
            using: &randomNumberGenerator,
        )

        try #expect(result.grantedGold == 20)
        try #expect(result.heroGrantedExperience == expectedHeroXP)
        try #expect(result.companionGrantedExperience == expectedCompanionXP)
        try #expect(result.hasGrantedExperience)
        try #expect(
            result.grantedMaterials
                == [ResourceAmount(.herbs, MysteryEffectApplier.materialQuantity(forLevel: 1))],
        )
        try #expect(save.roster.gold == 20)
        try #expect(
            save.homestead.balance(for: .herbs, roster: save.roster)
                >= MysteryEffectApplier.materialQuantity(forLevel: 1),
        )
        try #expect(result.heroProgressionBefore == heroProgressionBefore)
        try #expect(result.heroProgressionAfter == heroProgressionBefore.addingExperience(expectedHeroXP))
        try #expect(result.companionProgressionBefore == companionProgressionBefore)
        try #expect(
            result.companionProgressionAfter
                == companionProgressionBefore.addingExperience(expectedCompanionXP),
        )
        try #expect(
            save.roster.progression(for: hero) == heroProgressionBefore.addingExperience(expectedHeroXP),
        )
        try #expect(
            save.roster.progression(for: companion)
                == companionProgressionBefore.addingExperience(expectedCompanionXP),
        )
    }

    @Test func `mystery reward percent bonuses scale grants`() throws {
        let effects: [MysteryEffect] = [.gainGold(20), .gainMaterial(.herbs), .gainExperience]

        var baselineSave = SaveTestSupport.makeSave()
        var baselineRNG = SeededRandomNumberGenerator(seed: 1)
        let baseline = MysteryEffectApplier.apply(
            effects,
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &baselineSave,
            using: &baselineRNG,
        )

        var save = SaveTestSupport.makeSave()
        var rng = SeededRandomNumberGenerator(seed: 1)
        let boosted = MysteryEffectApplier.apply(
            effects,
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &rng,
            goldFoundPercent: 25,
            experienceEarnedPercent: 25,
            materialsFoundPercent: 25,
        )

        #expect(boosted.grantedGold == CombatRounding.scaled(baseline.grantedGold, byPercent: 25))
        #expect(boosted.heroGrantedExperience == CombatRounding.scaled(baseline.heroGrantedExperience, byPercent: 25))
        #expect(boosted.companionGrantedExperience == CombatRounding.scaled(baseline.companionGrantedExperience, byPercent: 25))
        let baseQuantity = MysteryEffectApplier.materialQuantity(forLevel: 1)
        try #expect(
            boosted.grantedMaterials == [ResourceAmount(.herbs, CombatRounding.scaled(baseQuantity, byPercent: 25))],
        )
    }

    @Test func `mystery experience grants the same amount across recipient levels`() throws {
        var save = SaveTestSupport.makeSave()
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = save.roster.activeCompanion
        save.roster.progressions[hero.id] = .at(level: 20)
        save.roster.progressions[companion.id] = .at(level: 5)
        let heroBefore = save.roster.progression(for: hero)
        let companionBefore = save.roster.progression(for: companion)
        let expectedHeroXP = 7
        let expectedCompanionXP = 7
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [.gainExperience],
            stageID: "chapter-1-stage-2",
            choiceID: "study",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )

        try #expect(result.heroGrantedExperience == expectedHeroXP)
        try #expect(result.companionGrantedExperience == expectedCompanionXP)
        try #expect(expectedHeroXP == expectedCompanionXP)
        try #expect(result.heroProgressionAfter == heroBefore.addingExperience(expectedHeroXP))
        try #expect(result.companionProgressionAfter == companionBefore.addingExperience(expectedCompanionXP))
    }

    @Test func `grant experience caps at three times required XP`() throws {
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

    @Test func `reward result reports only amounts accepted by wallets`() throws {
        var save = SaveTestSupport.makeSave()
        save.roster.gold = 995
        save.homestead = PlayerHomesteadState(
            resources: [.herbs: 997],
            nodeTiers: [:],
            pendingProduction: [.gold: 1, .herbs: 1],
            lastProductionAt: Date(),
        )
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let result = MysteryEffectApplier.apply(
            [.gainGold(10), .gainMaterial(.herbs)],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )

        try #expect(result.grantedGold == 3)
        try #expect(result.grantedMaterials == [ResourceAmount(.herbs, 4)])
        try #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        try #expect(save.homestead.resources[.herbs] == 1001)
    }

    @Test func `material quantity scales with level`() {
        #expect(MysteryEffectApplier.materialQuantity(forLevel: 1) == 4)
        #expect(MysteryEffectApplier.materialQuantity(forLevel: 50) == 18)
        #expect(
            MysteryEffectApplier.materialQuantity(forLevel: 50)
                > MysteryEffectApplier.materialQuantity(forLevel: 1),
        )
    }

    @Test func `generated item includes guaranteed affix and uses rolled rarity`() throws {
        var save = SaveTestSupport.makeSave()
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 11)

        let result = MysteryEffectApplier.apply(
            [.gainItem(MysteryItemPool(baseTypeID: "sapphire_ring", guaranteedAffixIDs: ["manabound"]))],
            stageID: "chapter-1-stage-2",
            choiceID: "harvest",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )

        let item = try #require(result.grantedItems.first)
        try #expect(item.baseType.id == "sapphire_ring")
        try #expect(item.affixes.contains { $0.id == "manabound" })
        try #expect(save.inventory.items.contains(where: { $0.id == item.id }))
        try #expect(item.rarity == .basic || item.rarity == .astral)
    }

    @Test func `resolved offer grants its exact item and secondary reward`() throws {
        var save = SaveTestSupport.makeSave()
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        var rng = SeededRandomNumberGenerator(seed: 42)
        let offer = MysteryEffectApplier.resolveOffer(
            choice: event.choices[0],
            encounterID: "spring",
            encounterLevel: 6,
            save: save,
            using: &rng,
        )
        let result = MysteryEffectApplier.apply(offer, save: &save)
        #expect(result.grantedItems == [offer.item])
        #expect(save.inventory.items.contains(offer.item))
        #expect(result.grantedMaterials == [ResourceAmount(.crystal, offer.bonus.amount)])
        #expect(MysteryEffectApplier.apply(offer, save: &save).isEmpty)
    }

    @Test func `special rolls stay inside the choice pool and fall back when owned`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let choice = event.choices[0]
        for tier in [ItemDropTier.trinket, .unique] {
            let matchingSeed = (UInt64(1) ... 1000).first { seed in
                var rng = SeededRandomNumberGenerator(seed: seed)
                return MysteryItemRarity.roll(using: &rng) == tier
            }
            let seed = try #require(matchingSeed)
            var save = SaveTestSupport.makeSave()
            var rng = SeededRandomNumberGenerator(seed: seed)
            let offer = MysteryEffectApplier.resolveOffer(
                choice: choice, encounterID: "spring", encounterLevel: 6, save: save, using: &rng,
            )
            let expectedID = tier == .trinket ? "icy_heart" : "rimeheart_locket"
            #expect(offer.item.templateID == expectedID)
            save.inventory.appendUniqueItem(offer.item)
            rng = SeededRandomNumberGenerator(seed: seed)
            let fallback = MysteryEffectApplier.resolveOffer(
                choice: choice, encounterID: "spring-again", encounterLevel: 6, save: save, using: &rng,
            )
            #expect(fallback.item.baseType.id == "sapphire_amulet")
            #expect(fallback.item.rarity == .astral)
        }
    }

    @Test func `mana berry harvest choice applies expected rewards`() throws {
        var save = SaveTestSupport.makeSave()
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        let harvest = try #require(event.choices.first { $0.id == "harvest-berries" })
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 3)

        let result = MysteryEffectApplier.apply(
            harvest.effects,
            stageID: "chapter-1-stage-2",
            choiceID: harvest.id,
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )

        try #expect(
            result.grantedMaterials
                .contains(ResourceAmount(.herbs, MysteryEffectApplier.materialQuantity(forLevel: 1))),
        )
        let ring = try #require(result.grantedItems.first)
        try #expect(ring.baseType.id == "sapphire_ring")
        try #expect(ring.affixes.contains { $0.id == "manabound" })
    }

    @Test func `shared mystery XP respects the smaller grant ceiling`() {
        var save = SaveTestSupport.makeSave()
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        save.roster.progressions[hero.id] = .at(level: 1)
        save.roster.progressions[companion.id] = .at(level: 30)
        let award = MysteryEffectApplier.experienceAward(encounterLevel: 50, roster: save.roster, percent: 25)
        #expect(award == 30)
        var rng = SeededRandomNumberGenerator(seed: 1)
        let result = MysteryEffectApplier.apply(
            [.gainExperience], stageID: "high-level", choiceID: "study", encounterLevel: 50,
            save: &save, using: &rng, experienceEarnedPercent: 25,
        )
        #expect(result.heroGrantedExperience == 30)
        #expect(result.companionGrantedExperience == 30)
    }

    @Test func `unlock combatant effects handle hero and companion idempotently`() throws {
        var save = SaveTestSupport.makeSave(roster: .freshStart)
        var randomNumberGenerator = SeededRandomNumberGenerator(seed: 1)

        let first = MysteryEffectApplier.apply(
            [.unlockCombatant("rogue")],
            stageID: "chapter-1-stage-8",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )
        try #expect(first.unlockedCombatantIDs == ["rogue"])
        try #expect(save.roster.isHeroUnlocked("rogue"))

        let second = MysteryEffectApplier.apply(
            [.unlockCombatant("rogue")],
            stageID: "chapter-1-stage-8",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )
        try #expect(second.unlockedCombatantIDs.isEmpty)

        let result = MysteryEffectApplier.apply(
            [.unlockCombatant("bear")],
            stageID: "chapter-1-stage-2",
            choiceID: "welcome",
            encounterLevel: 1,
            save: &save,
            using: &randomNumberGenerator,
        )

        try #expect(result.unlockedCombatantIDs == ["bear"])
        try #expect(save.roster.isCompanionUnlocked("bear"))
    }

    @Test func `resolved encounter level pulls far above content down to party ceiling`() throws {
        let lateStage = try #require(GameContent.chapters.last?.stages.first)
        let authoredLevel = StageCompletion.resolvedEncounterLevel(
            for: lateStage,
            in: GameContent.chapters,
        )
        #expect(authoredLevel > 5)

        var save = SaveTestSupport.makeSave()
        save.roster.progressions[save.roster.activeHeroID] = .at(level: 3)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 2)

        let clamped = MysteryEffectApplier.resolvedEncounterLevel(
            stage: lateStage,
            labyrinthNodeID: nil,
            save: save,
        )
        #expect(clamped == 5)

        save.roster.progressions[save.roster.activeHeroID] = .at(level: 99)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 99)
        let passthrough = MysteryEffectApplier.resolvedEncounterLevel(
            stage: lateStage,
            labyrinthNodeID: nil,
            save: save,
        )
        #expect(passthrough == authoredLevel)
    }

    @Test func `resolved encounter level clamps labyrinth node depth`() {
        var save = SaveTestSupport.makeSave()
        save.roster.progressions[save.roster.activeHeroID] = .at(level: 3)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 2)
        let deepID = "mystery-scaling-node"
        save.labyrinth.nodes[deepID] = LabyrinthNode(
            id: deepID,
            type: .mystery,
            enemyID: nil,
            depth: 30,
            clusterID: "mystery-scaling",
        )

        let clamped = MysteryEffectApplier.resolvedEncounterLevel(
            stage: GameContent.chapters[0].stages[0],
            labyrinthNodeID: deepID,
            save: save,
        )
        #expect(clamped == 5)
    }
}
