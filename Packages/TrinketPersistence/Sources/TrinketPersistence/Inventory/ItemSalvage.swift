import TrinketContent
import TrinketCore

public enum ItemSalvageFailure: Error, Equatable, Sendable {
    case itemNotFound
    case ineligible
}

enum ItemSalvageApplier {
    static func salvage(
        itemID: String, save: inout PlayerSave,
    ) -> Result<[ResourceAmount], ItemSalvageFailure> {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .failure(.itemNotFound)
        }
        let yields = ItemSalvage.yields(for: item)
        guard !yields.isEmpty else { return .failure(.ineligible) }
        save.roster.unequip(itemID: itemID)
        save.inventory.removeItem(id: itemID)
        let granted = save.grantMaterials(yields)
        return .success(granted)
    }
}

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func salvageItem(id: String) -> SaveTransactionResult<[ResourceAmount], ItemSalvageFailure> {
        persistAction(claim: .salvage(id), logging: "Failed to salvage item \(id)") { save in
            ItemSalvageApplier.salvage(itemID: id, save: &save)
        }
    }
}
