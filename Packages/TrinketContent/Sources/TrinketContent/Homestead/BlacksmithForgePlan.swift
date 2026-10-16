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
        using random: inout some RandomNumberGenerator,
    ) -> Result<Self, Rejection> {
        guard let recipe = BlacksmithRecipe.matching(recipeID),
              homestead.tier(for: .blacksmithForge) > 0 else { return .failure(.unavailable) }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        let uniqueIDs = Set(GameContent.uniqueItems.filter { $0.baseType.id == recipe.baseID }.map(\.templateID))
        let item = ItemRewardGenerator.generate(
            id: "forge-\(UUID().uuidString)",
            rewardLevel: rewardLevel,
            astralChanceBonusPercent: BlacksmithRecipe.astralWeightBonusPercent(
                blacksmithTier: homestead.tier(for: .blacksmithForge),
            ),
            allowedTiers: [.basic, .astral, .unique],
            ownedTrinketIDs: Set(inventory.lazy.filter(\.isTrinket).map(\.templateID)),
            ownedUniqueIDs: Set(inventory.lazy.filter { $0.rarity == .unique }.map(\.templateID)),
            eligibleUniqueIDs: uniqueIDs,
            fallbackBaseType: recipe.baseType,
            using: &random,
        )
        return .success(Self(recipe: recipe, item: item))
    }

    public func apply(
        inventory: inout [InventoryItem],
        homestead: inout PlayerHomesteadState,
        gold: inout Int,
    ) -> Result<InventoryItem, Rejection> {
        guard homestead.tier(for: .blacksmithForge) > 0 else { return .failure(.unavailable) }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: inventory) else {
            return .failure(.alreadyOwned)
        }
        guard homestead.canAfford(cost: recipe.cost, gold: gold) else { return .failure(.insufficientResources) }
        homestead.deductCost(recipe.cost, gold: &gold)
        inventory.append(item)
        return .success(item)
    }
}
