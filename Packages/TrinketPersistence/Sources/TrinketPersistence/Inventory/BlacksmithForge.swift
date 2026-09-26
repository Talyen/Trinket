import Foundation
import TrinketContent
import TrinketCore

public enum BlacksmithForgeFailure: Error, Equatable, Sendable {
    case unavailable
    case insufficientResources
    case alreadyOwned
    case invalidated
}

/// A roll is retained across persistence retries; presentation never grants it.
struct BlacksmithForgeAttempt {
    let recipe: BlacksmithRecipe
    let item: InventoryItem

    static func prepare(
        recipeID: String,
        save: PlayerSave,
        using random: inout some RandomNumberGenerator,
    ) -> Result<Self, BlacksmithForgeFailure> {
        guard let recipe = BlacksmithRecipe.matching(recipeID),
              save.homestead.tier(for: .blacksmithForge) > 0 else { return .failure(.unavailable) }
        guard affordable(recipe, in: save) else { return .failure(.insufficientResources) }
        let uniqueIDs = Set(GameContent.uniqueItems.filter { $0.baseType.id == recipe.baseID }.map(\.templateID))
        let item = ItemRewardGenerator.generate(
            id: "forge-\(UUID().uuidString)",
            rewardLevel: CampaignRewardLevel.resolve(in: save),
            astralChanceBonusPercent: BlacksmithRecipe.astralWeightBonusPercent(
                blacksmithTier: save.homestead.tier(for: .blacksmithForge),
            ),
            allowedTiers: [.basic, .astral, .unique],
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            eligibleUniqueIDs: uniqueIDs,
            fallbackBaseType: recipe.baseType,
            using: &random,
        )
        return .success(Self(recipe: recipe, item: item))
    }

    static func affordable(_ recipe: BlacksmithRecipe, in save: PlayerSave) -> Bool {
        save.homestead.canAfford(cost: recipe.cost, roster: save.roster)
    }

    func apply(to save: inout PlayerSave) -> Result<InventoryItem, BlacksmithForgeFailure> {
        guard save.homestead.tier(for: .blacksmithForge) > 0 else { return .failure(.unavailable) }
        guard !InventoryDuplicatePolicy.containsDuplicate(of: item, in: save.inventory.items) else {
            return .failure(.alreadyOwned)
        }
        guard Self.affordable(recipe, in: save) else { return .failure(.insufficientResources) }
        save.homestead.deductCost(recipe.cost, roster: &save.roster)
        save.inventory.appendUniqueItem(item)
        return .success(item)
    }
}

@MainActor
public extension PlayerSaveStore {
    func forgeBlacksmithItem(recipeID: String) async -> Result<InventoryItem, BlacksmithForgeFailure> {
        var random = SystemRandomNumberGenerator()
        let attempt: BlacksmithForgeAttempt
        switch BlacksmithForgeAttempt.prepare(recipeID: recipeID, save: currentSave, using: &random) {
        case let .success(value): attempt = value
        case let .failure(error): return .failure(error)
        }
        let result = await retryingTransientOperation {
            self.persistTransaction(logging: "Failed to forge Blacksmith item") { save in
                attempt.apply(to: &save)
            }
        } while: {
            if case .persistFailed = $0 {
                return true
            }
            return false
        }
        switch result {
        case let .committed(item): return .success(item)
        case let .rejected(error): return .failure(error)
        case .persistFailed, nil: return .failure(.invalidated)
        }
    }
}
