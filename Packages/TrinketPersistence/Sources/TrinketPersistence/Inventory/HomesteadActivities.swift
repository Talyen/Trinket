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
        let result = await retryingSaveTransaction {
            try prepareLocalProduction()
            return persistTransaction(logging: "Failed to transmute resource") { save, receipt -> Result<
                ResourceAmount,
                HomesteadActivityFailure,
            > in
                let before = save
                // Settle against the old Gold balance so spending cannot reopen past capped production.
                save.homestead.settleProduction(at: date, gold: save.roster.gold)
                guard ResourceTransmutation.apply(
                    from: source, to: destination, quantity: quantity, homestead: &save.homestead, gold: &save.roster.gold,
                ) else { return .failure(.unavailable) }
                receipt(.reward(from: before, to: save))
                return .success(ResourceAmount(destination, quantity))
            }
        }
        switch result {
        case let .committed(amount): return .success(amount)
        case let .rejected(error): return .failure(error)
        case .persistFailed, nil: return .failure(.invalidated)
        }
    }

    func inscribeItem(itemID: String, index: Int, affixID: String) async -> Result<InventoryItem, HomesteadActivityFailure> {
        guard homestead.tier(for: .runesmithWorkshop) > 0,
              let item = inventory.items.first(where: { $0.id == itemID }) else { return .failure(.unavailable) }
        var random = SystemRandomNumberGenerator()
        guard let plan = ItemInscriptionPlan.prepare(item: item, index: index, affixID: affixID, using: &random) else {
            return .failure(.unavailable)
        }
        let result = await retryingSaveTransaction {
            persistTransaction(logging: "Failed to inscribe item") { save, receipt -> Result<InventoryItem, HomesteadActivityFailure> in
                guard save.homestead.tier(for: .runesmithWorkshop) > 0,
                      let position = save.inventory.items.firstIndex(where: { $0.id == itemID }),
                      save.inventory.items[position] == plan.original,
                      save.homestead.canAfford(cost: plan.cost, gold: save.roster.gold) else { return .failure(.unavailable) }
                let before = save
                save.homestead.deductCost(plan.cost, gold: &save.roster.gold)
                save.inventory.items[position] = plan.item
                receipt(.reward(from: before, to: save))
                return .success(plan.item)
            }
        }
        switch result {
        case let .committed(item): return .success(item)
        case let .rejected(error): return .failure(error)
        case .persistFailed, nil: return .failure(.invalidated)
        }
    }

    func setItemWish(_ templateID: String?) async -> Result<Void, HomesteadActivityFailure> {
        let result = await retryingSaveTransaction {
            persistTransaction(logging: "Failed to update item wish") { save -> Result<Void, HomesteadActivityFailure> in
                guard save.homestead.tier(for: .wishingWell) > 0,
                      templateID == nil || ItemWish.validTarget(templateID, inventory: save.inventory.items) != nil else {
                    return .failure(.unavailable)
                }
                save.homestead.wishedTemplateID = templateID
                return .success(())
            }
        }
        switch result {
        case .committed: return .success(())
        case let .rejected(error): return .failure(error)
        case .persistFailed, nil: return .failure(.invalidated)
        }
    }
}
