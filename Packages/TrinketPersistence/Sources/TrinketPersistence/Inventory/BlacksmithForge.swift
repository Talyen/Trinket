import TrinketContent
import TrinketCore

public enum BlacksmithForgeFailure: Error, Equatable, Sendable {
    case unavailable
    case insufficientResources
    case alreadyOwned
    case invalidated
}

enum BlacksmithForgeApplier {
    static func prepare(
        recipeID: String,
        save: PlayerSave,
        using random: inout some RandomNumberGenerator,
    ) -> Result<BlacksmithForgePlan, BlacksmithForgeFailure> {
        BlacksmithForgePlan.prepare(
            recipeID: recipeID,
            rewardLevel: CampaignRewardLevel.resolve(in: save),
            inventory: save.inventory.items,
            homestead: save.homestead,
            gold: save.roster.gold,
            unlockedRecipeIDs: save.library.isReadable ? save.library.progress.unlockedRecipeIDs : [],
            using: &random,
        ).mapError(BlacksmithForgeFailure.init)
    }

    static func apply(
        _ plan: BlacksmithForgePlan,
        to save: inout PlayerSave,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> Result<InventoryItem, BlacksmithForgeFailure> {
        let before = save
        let result = plan.apply(
            inventory: &save.inventory.items,
            homestead: &save.homestead,
            gold: &save.roster.gold,
            unlockedRecipeIDs: save.library.isReadable ? save.library.progress.unlockedRecipeIDs : [],
        ).mapError(BlacksmithForgeFailure.init)
        if case .success = result {
            recordReceipt(.reward(from: before, to: save))
        }
        return result
    }
}

private extension BlacksmithForgeFailure {
    init(_ rejection: BlacksmithForgePlan.Rejection) {
        switch rejection {
        case .unavailable: self = .unavailable
        case .insufficientResources: self = .insufficientResources
        case .alreadyOwned: self = .alreadyOwned
        }
    }
}

@MainActor
public extension PlayerSaveStore {
    func forgeBlacksmithItem(recipeID: String) async -> Result<InventoryItem, BlacksmithForgeFailure> {
        guard EquipmentRecipe.matching(recipeID)?.buildingID == .blacksmithForge else { return .failure(.unavailable) }
        return await craftEquipmentItem(recipeID: recipeID)
    }

    func craftEquipmentItem(recipeID: String) async -> Result<InventoryItem, BlacksmithForgeFailure> {
        var random = SystemRandomNumberGenerator()
        let plan: BlacksmithForgePlan
        switch BlacksmithForgeApplier.prepare(recipeID: recipeID, save: currentSave, using: &random) {
        case let .success(value): plan = value
        case let .failure(error): return .failure(error)
        }
        let result = await retryingSaveTransaction {
            self.persistTransaction(logging: "Failed to forge Blacksmith item") { save, recordReceipt in
                BlacksmithForgeApplier.apply(plan, to: &save, recordReceipt: recordReceipt)
            }
        }
        switch result {
        case let .committed(item): return .success(item)
        case let .rejected(error): return .failure(error)
        case .persistFailed, nil: return .failure(.invalidated)
        }
    }
}
