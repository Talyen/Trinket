import Testing
import TrinketCore
@testable import TrinketContent

struct LibraryResearchTests {
    @Test func `catalog lookups preserve authored order and missing results`() {
        let recipes = EquipmentRecipe.all + EquipmentRecipe.archery + EquipmentRecipe.outfitter + EquipmentRecipe.focusedBlacksmith
        for recipe in recipes {
            #expect(EquipmentRecipe.matching(recipe.id) == recipes.first { $0.id == recipe.id })
            #expect(recipe.researchID == ResearchProject.all.first { $0.recipeID == recipe.id }?.id)
        }
        #expect(EquipmentRecipe.matching("missing-recipe") == nil)
        for project in ResearchProject.all {
            #expect(ResearchProject.matching(project.id) == ResearchProject.all.first { $0.id == project.id })
        }
        #expect(ResearchProject.matching("missing-project") == nil)
        for event in RecruitEventPool.all {
            if let combatantID = event.unlockCombatantID {
                #expect(RecruitEventPool.event(unlocking: combatantID) == RecruitEventPool.all
                    .first { $0.unlockCombatantID == combatantID })
            }
        }
        #expect(RecruitEventPool.event(unlocking: "missing-combatant") == nil)
    }

    @Test func `encounters do not satisfy defeat studies and upgrades retain earned facts`() {
        var history = LibraryProgress()
        for id in ["slime", "goblin", "the_blight_treant"] {
            history.encounter(id)
        }
        #expect(history.evaluate(libraryTier: 4).isEmpty)
        for _ in 0 ..< 3 {
            history.defeat("slime")
        }
        #expect(history.evaluate(libraryTier: 4).isEmpty)
        history.defeat("goblin")
        history.defeat("the_blight_treant")
        #expect(history.evaluate(libraryTier: 0).isEmpty)
        #expect(history.evaluate(libraryTier: 1) == ["forest-field-notes"])
        #expect(history.unlockedRecipeIDs == ["archery-shortbow-poison"])
        #expect(history.evaluate(libraryTier: 1).isEmpty)
        history.merge(LibraryProgress())
        #expect(history.unlockedRecipeIDs.contains("archery-shortbow-poison"))
    }

    @Test func `focused crafts keep their exact base and keyword at both eligible rarities`() throws {
        let homestead = PlayerHomesteadState(
            resources: [.wood: 500, .iron: 500, .hide: 500, .herbs: 500],
            nodeTiers: [.archeryRange: 4],
        )
        let odds = ItemLootPolicy.probabilities(
            level: 40,
            bossContent: false,
            astralChanceBonusPercent: 30,
            availableTiers: [.basic, .astral],
        )
        var seeds: [ItemDropTier: UInt64] = [:]
        for seed in UInt64(0) ..< 100 where seeds.count < 2 {
            var random = SeededRandomNumberGenerator(seed: seed)
            seeds[ItemLootPolicy.roll(probabilities: odds, using: &random)] = seed
        }
        try #require(seeds.count == 2)
        for recipe in EquipmentRecipe.archery where recipe.researchID != nil {
            for (tier, seed) in seeds {
                var random = SeededRandomNumberGenerator(seed: seed)
                let plan = try BlacksmithForgePlan.prepare(
                    recipeID: recipe.id,
                    rewardLevel: 40,
                    inventory: [],
                    homestead: homestead,
                    gold: 0,
                    unlockedRecipeIDs: [recipe.id],
                    using: &random,
                ).get()
                #expect(plan.item.baseType.id == recipe.baseID)
                #expect(plan.item.rarity == (tier == .basic ? .basic : .astral))
                let keyword = try #require(recipe.requiredKeyword)
                #expect(plan.item.affixes.contains { $0.keywords.contains(keyword) })
                var inventory: [InventoryItem] = []
                var after = homestead
                var gold = 0
                #expect(throws: BlacksmithForgePlan.Rejection.self) {
                    try plan.apply(inventory: &inventory, homestead: &after, gold: &gold).get()
                }
                #expect(inventory.isEmpty && after == homestead)
            }
        }
    }
}
