import Foundation

/// A forge roll is immutable; retries revalidate the current values before spending.
public struct BlacksmithForgePlan: Sendable {
    public enum Rejection: Error, Equatable, Sendable {
        case unavailable
        case insufficientResources
        case alreadyOwned
    }

    public let recipe: BlacksmithRecipe
    public let item: InventoryItem

    private static let uniqueIDsByBase = Dictionary(grouping: GameContent.uniqueItems, by: { $0.baseType.id })
        .mapValues { Set($0.lazy.map(\.templateID)) }

    public static func prepare(
        recipeID: String,
        rewardLevel: Int,
        inventory: [InventoryItem],
        homestead: PlayerHomesteadState,
        gold: Int,
        unlockedRecipeIDs: Set<String> = [],
        partyBias: PartyLootBias = PartyLootBias(),
        using random: inout some RandomNumberGenerator,
    ) -> Result<Self, Rejection> {
        guard let recipe = BlacksmithRecipe.matching(recipeID),
              isAvailable(recipe, homestead: homestead, unlockedRecipeIDs: unlockedRecipeIDs) else { return .failure(.unavailable) }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        var ownedUniqueIDs: Set<String> = []
        for item in inventory where item.rarity == .unique {
            ownedUniqueIDs.insert(item.templateID)
        }
        let item = ItemRewardGenerator.generate(
            id: "forge-\(UUID().uuidString)",
            rewardLevel: rewardLevel,
            astralChanceBonusPercent: BlacksmithRecipe.astralWeightBonusPercent(
                blacksmithTier: homestead.tier(for: recipe.buildingID),
            ),
            allowedTiers: recipe.requiredKeyword == nil ? [.basic, .astral, .unique] : [.basic, .astral],
            requiredKeyword: recipe.requiredKeyword,
            ownedTrinketIDs: [],
            ownedUniqueIDs: ownedUniqueIDs,
            partyBias: partyBias,
            eligibleUniqueIDs: uniqueIDsByBase[recipe.baseID] ?? [],
            fallbackBaseType: recipe.baseType,
            baseTypes: [recipe.baseType],
            using: &random,
        )
        return .success(Self(recipe: recipe, item: item))
    }

    public func apply(
        inventory: inout [InventoryItem],
        homestead: inout PlayerHomesteadState,
        gold: inout Int,
        unlockedRecipeIDs: Set<String> = [],
    ) -> Result<InventoryItem, Rejection> {
        guard Self.isAvailable(recipe, homestead: homestead, unlockedRecipeIDs: unlockedRecipeIDs) else { return .failure(.unavailable) }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: inventory) else {
            return .failure(.alreadyOwned)
        }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        homestead.deductCost(recipe.cost, gold: &gold)
        inventory.append(item)
        return .success(item)
    }

    private static func isAvailable(
        _ recipe: BlacksmithRecipe, homestead: PlayerHomesteadState, unlockedRecipeIDs: Set<String>,
    ) -> Bool {
        homestead.tier(for: recipe.buildingID) > 0
            && (recipe.researchID == nil || unlockedRecipeIDs.contains(recipe.id))
    }
}
