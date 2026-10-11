import TrinketContent
import TrinketCore

public enum ItemSalvageFailure: Error, Equatable, Sendable {
    case itemNotFound
    case ineligible
}

enum ItemSalvageApplier {
    static func salvage(
        itemID: String, save: inout PlayerSave,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> Result<[ResourceAmount], ItemSalvageFailure> {
        guard let item = save.inventory.items.first(where: { $0.id == itemID }) else {
            return .failure(.itemNotFound)
        }
        let yields = ItemSalvage.yields(for: item)
        guard !yields.isEmpty else { return .failure(.ineligible) }
        save.roster.unequip(itemID: itemID)
        save.inventory.removeItem(id: itemID)
        let granted = save.grantMaterials(yields)
        recordReceipt(SaveEconomicReceipt(kind: .reward, effects: .committed(
            claim: .salvage(itemID), materials: Dictionary(uniqueKeysWithValues: granted.map { ($0.resource, $0.quantity) }),
        )))
        return .success(granted)
    }
}

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func salvageItem(id: String) -> SaveTransactionResult<[ResourceAmount], ItemSalvageFailure> {
        persistTransaction(logging: "Failed to salvage item \(id)") { save, recordReceipt in
            ItemSalvageApplier.salvage(itemID: id, save: &save, recordReceipt: recordReceipt)
        }
    }
}
