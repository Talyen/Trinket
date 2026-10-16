import Testing
import TrinketCore
@testable import TrinketContent

struct BlacksmithForgePlanTests {
    private func fundedHomestead() -> PlayerHomesteadState {
        PlayerHomesteadState(
            resources: [.iron: 500, .wood: 500, .hide: 500],
            nodeTiers: [.blacksmithForge: 1],
        )
    }

    @Test func `recipes have distinct identities artwork and a salvage sink`() throws {
        try #require(!BlacksmithRecipe.all.isEmpty)
        #expect(Set(BlacksmithRecipe.all.map(\.id)).count == BlacksmithRecipe.all.count)
        for recipe in BlacksmithRecipe.all {
            #expect(recipe.cost.allSatisfy { $0.quantity > 0 })
            #expect(ArtCatalog.itemArtByID["\(recipe.baseID)-basic"] != nil)
            var random = SeededRandomNumberGenerator(seed: 11)
            let item = ItemGenerator().generate(
                id: "\(recipe.baseID)-astral", baseType: recipe.baseType, rarity: .astral, using: &random,
            )
            let yields = ItemSalvage.yields(for: item)
            #expect(recipe.cost.reduce(0) { $0 + $1.quantity } > yields.reduce(0) { $0 + $1.quantity })
            for cost in recipe.cost {
                #expect(cost.quantity > (yields.first { $0.resource == cost.resource }?.quantity ?? 0))
            }
        }
    }

    @Test func `forging honors recipe bases rarities and unique ownership`() throws {
        var homestead = fundedHomestead()
        homestead.nodeTiers[.moonlitSanctum] = 4
        var inventory: [InventoryItem] = []
        let cases = try rarityCases(blacksmithTier: homestead.tier(for: .blacksmithForge))
        for recipe in BlacksmithRecipe.all {
            for (rarity, seed) in cases {
                var random = SeededRandomNumberGenerator(seed: seed)
                let attempt = try BlacksmithForgePlan.prepare(
                    recipeID: recipe.id, rewardLevel: 40, inventory: inventory,
                    homestead: homestead, gold: 0, using: &random,
                ).get()
                #expect(attempt.item.baseType.id == recipe.baseID)
                #expect(!attempt.item.isTrinket)
                #expect(attempt.item.rarity == rarity)
            }
        }
        let uniqueSeed = try #require(cases.first { $0.0 == .unique }?.1)
        inventory = GameContent.uniqueItems
        for recipe in BlacksmithRecipe.all {
            var random = SeededRandomNumberGenerator(seed: uniqueSeed)
            let attempt = try BlacksmithForgePlan.prepare(
                recipeID: recipe.id, rewardLevel: 40, inventory: inventory,
                homestead: homestead, gold: 0, using: &random,
            ).get()
            #expect(attempt.item.rarity != .unique)
            #expect(attempt.item.baseType.id == recipe.baseID)
        }
    }

    private func rarityCases(blacksmithTier: Int) throws -> [(Rarity, UInt64)] {
        // Content owns odds and cumulative boundaries. Select one input per path
        // cheaply, then exercise real forging instead of generating 1,200 items.
        let probabilities = ItemLootPolicy.probabilities(
            level: 40, bossContent: false,
            astralChanceBonusPercent: BlacksmithRecipe.astralWeightBonusPercent(
                blacksmithTier: blacksmithTier,
            ),
            availableTiers: [.basic, .astral, .unique],
        )
        var cases: [(Rarity, UInt64)] = []
        for seed in UInt64(0) ..< 100 {
            var random = SeededRandomNumberGenerator(seed: seed)
            let rarity: Rarity
            switch ItemLootPolicy.roll(probabilities: probabilities, using: &random) {
            case .basic: rarity = .basic
            case .astral: rarity = .astral
            case .unique: rarity = .unique
            case .trinket: continue
            }
            if !cases.contains(where: { $0.0 == rarity }) {
                cases.append((rarity, seed))
            }
            if cases.count == 3 {
                break
            }
        }
        try #require(cases.count == 3, "Forge fixture must exercise Basic, Astral and Unique paths")
        return cases
    }
}
