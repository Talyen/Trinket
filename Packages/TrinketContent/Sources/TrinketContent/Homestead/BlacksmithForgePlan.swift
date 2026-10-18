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

    public static func prepare(
        recipeID: String,
        rewardLevel: Int,
        inventory: [InventoryItem],
        homestead: PlayerHomesteadState,
        gold: Int,
        unlockedRecipeIDs: Set<String> = [],
        using random: inout some RandomNumberGenerator,
    ) -> Result<Self, Rejection> {
        guard let recipe = BlacksmithRecipe.matching(recipeID),
              homestead.tier(for: recipe.buildingID) > 0 else { return .failure(.unavailable) }
        guard recipe.researchID == nil || unlockedRecipeIDs.contains(recipe.id) else { return .failure(.unavailable) }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        let uniqueIDs = Set(GameContent.uniqueItems.filter { $0.baseType.id == recipe.baseID }.map(\.templateID))
        let item = ItemRewardGenerator.generate(
            id: "forge-\(UUID().uuidString)",
            rewardLevel: rewardLevel,
            astralChanceBonusPercent: BlacksmithRecipe.astralWeightBonusPercent(
                blacksmithTier: homestead.tier(for: recipe.buildingID),
            ),
            allowedTiers: recipe.requiredKeyword == nil ? [.basic, .astral, .unique] : [.basic, .astral],
            requiredKeyword: recipe.requiredKeyword,
            ownedTrinketIDs: Set(inventory.lazy.filter(\.isTrinket).map(\.templateID)),
            ownedUniqueIDs: Set(inventory.lazy.filter { $0.rarity == .unique }.map(\.templateID)),
            eligibleUniqueIDs: uniqueIDs,
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
        guard homestead.tier(for: recipe.buildingID) > 0 else { return .failure(.unavailable) }
        guard recipe.researchID == nil || unlockedRecipeIDs.contains(recipe.id) else { return .failure(.unavailable) }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: inventory) else {
            return .failure(.alreadyOwned)
        }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        homestead.deductCost(recipe.cost, gold: &gold)
        inventory.append(item)
        return .success(item)
    }
}
