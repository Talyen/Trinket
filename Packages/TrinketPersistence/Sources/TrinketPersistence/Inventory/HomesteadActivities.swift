import Foundation
import TrinketContent
import TrinketCore

public enum HomesteadActivityFailure: Error, Equatable, Sendable {
    case unavailable
    case invalidated
}

@MainActor
public extension PlayerSaveStore {
    func transmuteResource(
        from source: HomesteadResource, to destination: HomesteadResource, quantity: Int, at date: Date = Date(),
    ) async -> Result<ResourceAmount, HomesteadActivityFailure> {
        await retryingSaveAction(invalidated: .invalidated) {
            try prepareLocalProduction()
            return persistAction(logging: "Failed to transmute resource") { save -> Result<
                ResourceAmount,
                HomesteadActivityFailure,
            > in
                // Settle against the old Gold balance so spending cannot reopen past capped production.
                save.homestead.settleProduction(at: date, gold: save.roster.gold)
                guard ResourceTransmutation.apply(
                    from: source, to: destination, quantity: quantity, homestead: &save.homestead, gold: &save.roster.gold,
                ) else { return .failure(.unavailable) }
                return .success(ResourceAmount(destination, quantity))
            }
        }
    }

    func inscribeItem(itemID: String, index: Int, affixID: String) async -> Result<InventoryItem, HomesteadActivityFailure> {
        guard homestead.tier(for: .runesmithWorkshop) > 0,
              let item = inventory.items.first(where: { $0.id == itemID }) else { return .failure(.unavailable) }
        var random = SystemRandomNumberGenerator()
        guard let plan = ItemInscriptionPlan.prepare(item: item, index: index, affixID: affixID, using: &random) else {
            return .failure(.unavailable)
        }
        return await retryingSaveAction(invalidated: .invalidated) {
            persistAction(logging: "Failed to inscribe item") { save -> Result<InventoryItem, HomesteadActivityFailure> in
                guard save.homestead.tier(for: .runesmithWorkshop) > 0,
                      let position = save.inventory.items.firstIndex(where: { $0.id == itemID }),
                      save.inventory.items[position] == plan.original,
                      save.homestead.canAfford(cost: plan.cost, gold: save.roster.gold) else { return .failure(.unavailable) }
                save.homestead.deductCost(plan.cost, gold: &save.roster.gold)
                save.inventory.items[position] = plan.item
                return .success(plan.item)
            }
        }
    }

    func setItemWish(_ templateID: String?) async -> Result<Void, HomesteadActivityFailure> {
        await retryingSaveAction(invalidated: .invalidated) {
            persistTransaction(logging: "Failed to update item wish") { save -> Result<Void, HomesteadActivityFailure> in
                guard save.homestead.tier(for: .wishingWell) > 0,
                      templateID == nil || ItemWish.validTarget(templateID, inventory: save.inventory.items) != nil else {
                    return .failure(.unavailable)
                }
                save.homestead.wishedTemplateID = templateID
                return .success(())
            }
        }
    }
}
