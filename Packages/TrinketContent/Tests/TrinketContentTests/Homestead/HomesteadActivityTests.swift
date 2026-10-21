import Testing
import TrinketCore
@testable import TrinketContent

struct HomesteadActivityTests {
    @Test(arguments: HomesteadResource.allCases, HomesteadResource.allCases)
    func `conversion conserves each batch including canonical gold`(source: HomesteadResource, destination: HomesteadResource) {
        for quantity in [1, 10] {
            var state = PlayerHomesteadState(
                resources: Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.filter { $0 != .gold }.map { ($0, 20) }),
                nodeTiers: [.transmutationCrucible: 1],
            )
            var gold = 20
            let before = state
            let applied = ResourceTransmutation.apply(from: source, to: destination, quantity: quantity, homestead: &state, gold: &gold)
            #expect(applied == (source != destination))
            for resource in HomesteadResource.allCases {
                let expected = source == destination ? 20 : 20 + (resource == destination ? quantity : 0) -
                    (resource == source ? quantity : 0)
                #expect(state.balance(for: resource, gold: gold) == expected)
            }
            #expect(state.pendingProduction == before.pendingProduction)
            #expect(state.rewardRemainders == before.rewardRemainders)
            #expect(state.resources[.gold] == nil)
        }
    }

    @Test func `conversion rejects bad amounts capacity funds and unbuilt crucible without mutation`() {
        var state = PlayerHomesteadState(resources: [.wood: 20, .gems: Int.max], nodeTiers: [.transmutationCrucible: 1])
        var gold = GoldBalance.maximum
        let initial = state
        for quantity in [Int.min, 0, 2, 9, 11, Int.max] {
            #expect(!ResourceTransmutation.apply(from: .wood, to: .stone, quantity: quantity, homestead: &state, gold: &gold))
        }
        #expect(!ResourceTransmutation.apply(from: .wood, to: .gems, quantity: 1, homestead: &state, gold: &gold))
        #expect(!ResourceTransmutation.apply(from: .wood, to: .gold, quantity: 1, homestead: &state, gold: &gold))
        #expect(!ResourceTransmutation.apply(from: .hide, to: .wood, quantity: 1, homestead: &state, gold: &gold))
        #expect(state == initial && gold == GoldBalance.maximum)
        state.nodeTiers = [:]
        let unbuilt = state
        #expect(!ResourceTransmutation.apply(from: .wood, to: .stone, quantity: 1, homestead: &state, gold: &gold))
        #expect(state == unbuilt)
    }

    @Test func `inscription preserves other exact powers and permanently restricts one position`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "greatsword"))
        var random = SeededRandomNumberGenerator(seed: 91)
        let original = ItemGenerator().generate(id: "inscription-test", baseType: base, rarity: .astral, fixedAffixCount: 3, using: &random)
        let choice = try #require(ItemInscriptionPlan.choices(for: original, index: 1).first)
        let plan = try #require(ItemInscriptionPlan.prepare(item: original, index: 1, affixID: choice.id, using: &random))
        #expect(plan.item.id == original.id && plan.item.templateID == original.templateID)
        #expect(plan.item.affixes.count == original.affixes.count)
        #expect(plan.item.inscribedAffixIndex == 1)
        for index in [0, 2] {
            #expect(plan.item.affixes[index] == original.affixes[index])
            #expect(plan.item.affixPowers?[index] == original.affixPowers?[index])
        }
        #expect(ItemInscriptionPlan.choices(for: plan.item, index: 0).isEmpty)
        #expect(ItemInscriptionPlan.prepare(item: plan.item, index: 0, affixID: choice.id, using: &random) == nil)
        let rerolled = try #require(ItemInscriptionPlan.prepare(item: plan.item, index: 1, affixID: choice.id, using: &random))
        #expect(rerolled.item.inscribedAffixIndex == 1)
        let otherIDs = Set(plan.item.affixes.enumerated().filter { $0.offset != 1 }.map(\.element.id))
        #expect(ItemInscriptionPlan.choices(for: plan.item, index: 1).allSatisfy { !otherIDs.contains($0.id) && $0.isEligible(for: base) })
        #expect(GameContent.uniqueItems.allSatisfy { !ItemInscriptionPlan.isEligible($0) })
        #expect(GameContent.trinketItems.allSatisfy { !ItemInscriptionPlan.isEligible($0) })
    }

    @Test func `corruption preserves inscription position and inscription clears only replaced corruption mark`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "leather_armor"))
        var random = SeededRandomNumberGenerator(seed: 123)
        let original = ItemGenerator().generate(
            id: "corrupt-inscription",
            baseType: base,
            rarity: .basic,
            fixedAffixCount: 2,
            using: &random,
        )
        let first = try #require(ItemInscriptionPlan.prepare(item: original, index: 0, affixID: original.affixes[0].id, using: &random))
        let corrupted = try #require(ItemCorruption.apply(
            kinds: [.replaceAffix, .addAffix, .bumpUp, .upgradeRarity],
            to: first.item,
            using: &random,
        )).item
        #expect(corrupted.inscribedAffixIndex == 0 && corrupted.rarity == .astral)
        let choice = try #require(ItemInscriptionPlan.choices(for: corrupted, index: 0).first)
        let next = try #require(ItemInscriptionPlan.prepare(item: corrupted, index: 0, affixID: choice.id, using: &random))
        #expect(next.item.isCorrupted)
        #expect(!next.item.affixes[0].isCorrupted)
        #expect(next.cost == [ResourceAmount(.iron, 16), ResourceAmount(.gems, 8)])
        for index in corrupted.affixes.indices.dropFirst() {
            #expect(next.item.affixes[index] == corrupted.affixes[index])
            #expect(next.item.affixPowers?[index] == corrupted.affixPowers?[index])
        }
    }

    @Test func `research yields nine valid recipes and focused workshops preserve guarantees`() throws {
        #expect(ResearchProject.all.count == 9)
        #expect(ResearchProject.matching("companion-chronicles") == nil)
        #expect(ResearchProject.matching("spire-records") == nil)
        var history = LibraryProgress()
        for enemy in GameContent.enemies {
            history.defeat(enemy.id)
        }
        #expect(history.evaluate(libraryTier: 3).count == 9)
        let state = PlayerHomesteadState(
            resources: Dictionary(uniqueKeysWithValues: HomesteadResource.allCases.filter { $0 != .gold }.map { ($0, 1000) }),
            nodeTiers: [.blacksmithForge: 4, .archeryRange: 4, .woolTailoring: 4],
        )
        for project in ResearchProject.all {
            let recipe = try #require(project.recipeID.flatMap(EquipmentRecipe.matching))
            let keyword = try #require(recipe.requiredKeyword)
            for seed in UInt64(0) ..< 20 {
                var random = SeededRandomNumberGenerator(seed: seed)
                let plan = try BlacksmithForgePlan.prepare(
                    recipeID: recipe.id,
                    rewardLevel: 40,
                    inventory: [],
                    homestead: state,
                    gold: 0,
                    unlockedRecipeIDs: history.unlockedRecipeIDs,
                    using: &random,
                ).get()
                #expect(plan.item.baseType.id == recipe.baseID)
                #expect(plan.item.rarity != .unique && !plan.item.isTrinket)
                #expect(plan.item.affixes.contains { $0.keywords.contains(keyword) })
            }
        }
    }

    @Test func `wish coin selects wished item or strictly another candidate and handles exhausted eligibility`() throws {
        let candidates = Array(GameContent.uniqueItems.prefix(3))
        let wish = try #require(candidates.first)
        var results: Set<String> = []
        for seed in UInt64(0) ..< 32 {
            var expected = SeededRandomNumberGenerator(seed: seed)
            let picksWish = Int.random(in: 0 ... 1, using: &expected) == 0
            var random = SeededRandomNumberGenerator(seed: seed)
            let item = ItemWish.select(from: candidates, wishedTemplateID: wish.templateID, using: &random)
            #expect((item == wish) == picksWish)
            results.insert(item.templateID)
        }
        #expect(results.count == 3)
        var random = SeededRandomNumberGenerator(seed: 4)
        #expect(ItemWish.select(from: [wish], wishedTemplateID: wish.templateID, using: &random) == wish)
        #expect(ItemWish.validTarget(wish.templateID, inventory: [wish]) == nil)
        #expect(ItemWish.validTarget("unknown", inventory: []) == nil)
        let trinket = try #require(GameContent.trinketItems.first)
        #expect(ItemWish.select(from: [trinket], wishedTemplateID: wish.templateID, using: &random) == trinket)
    }
}

extension HomesteadActivityTests {
    @Test func `wishes preserve category odds and respect category and pool exclusions`() throws {
        let wish = try #require(GameContent.uniqueItems.first)
        for seed in UInt64(0) ..< 100 {
            var ordinaryRandom = SeededRandomNumberGenerator(seed: seed)
            var wishedRandom = SeededRandomNumberGenerator(seed: seed)
            let ordinary = ItemRewardGenerator.generate(
                id: "loot",
                rewardLevel: 40,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                using: &ordinaryRandom,
            )
            let wished = ItemRewardGenerator.generate(
                id: "loot",
                rewardLevel: 40,
                wishedTemplateID: wish.templateID,
                ownedTrinketIDs: [],
                ownedUniqueIDs: [],
                using: &wishedRandom,
            )
            #expect(ordinary.rarity == wished.rarity && ordinary.isTrinket == wished.isTrinket)
            if ordinary.rarity != .unique {
                #expect(ordinary == wished)
            }
        }
        let other = try #require(GameContent.uniqueItems.first { $0.templateID != wish.templateID })
        for owned in [Set<String>(), [wish.templateID]] {
            var random = SeededRandomNumberGenerator(seed: 15)
            let item = ItemRewardGenerator.generate(
                id: "restricted",
                rewardLevel: 40,
                allowedTiers: [.unique],
                wishedTemplateID: wish.templateID,
                ownedTrinketIDs: [],
                ownedUniqueIDs: owned,
                eligibleUniqueIDs: [other.templateID],
                using: &random,
            )
            #expect(item == other)
        }
    }

    @Test func `inscription and generator roll affixes when basic matches astral`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "greatsword"))
        let nullifying = try #require(GameContent.itemAffixDefinition(matching: "nullifying"))
        #expect(nullifying.basic == nullifying.astral)
        #expect(nullifying.basic.hasRollableMagnitudes)

        var inscriptionRolledToTwo = false
        var generatorRolledToTwo = false
        for seed: UInt64 in 0 ..< 50 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let item = ItemGenerator().generate(
                id: "test-\(seed)",
                baseType: base,
                rarity: .basic,
                fixedAffixCount: 1,
                guaranteedAffixIDs: ["nullifying"],
                using: &rng,
            )
            if let power = item.affixPowers?[0], power.triggers.holyDamagePurgeCount == 2 {
                generatorRolledToTwo = true
            }

            var inscribeRng = SeededRandomNumberGenerator(seed: seed)
            if let plan = ItemInscriptionPlan.prepare(item: item, index: 0, affixID: "nullifying", using: &inscribeRng),
               let power = plan.item.affixPowers?[0],
               power.triggers.holyDamagePurgeCount == 2 {
                inscriptionRolledToTwo = true
                #expect(plan.item.affixes[0].description.contains("Purge 2 buffs"))
            }

            if generatorRolledToTwo, inscriptionRolledToTwo {
                break
            }
        }
        #expect(generatorRolledToTwo)
        #expect(inscriptionRolledToTwo)
    }
}
