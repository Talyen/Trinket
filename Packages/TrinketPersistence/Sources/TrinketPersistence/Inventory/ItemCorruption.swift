import TrinketContent
import TrinketCore

public enum ItemCorruptionFailure: Error, Equatable, Sendable {
    case itemNotFound
    case alreadyCorrupted
    case ineligible
}

enum ItemCorruptionApplier {
    static func corrupt(
        itemID: String,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Result<ItemCorruptionDetail, ItemCorruptionFailure> {
        guard let index = save.inventory.items.firstIndex(where: { $0.id == itemID }) else {
            return .failure(.itemNotFound)
        }
        let item = save.inventory.items[index]
        guard !item.isCorrupted, !item.hasCorruptedAffix else { return .failure(.alreadyCorrupted) }
        guard let result = ItemCorruption.corrupt(item, using: &randomNumberGenerator) else {
            return .failure(.ineligible)
        }
        save.inventory.items[index] = result.item
        return .success(result)
    }

    static func recordCorruptionAltarEncounter(save: inout PlayerSave) {
        save.corruptionAltarCooldownRemaining = PlayerSave.corruptionAltarCooldownAfterEncounter
    }

    static func noteMysteryCompleted(save: inout PlayerSave) {
        if save.corruptionAltarCooldownRemaining > 0 {
            save.corruptionAltarCooldownRemaining -= 1
        }
    }
}

@MainActor
public extension PlayerSaveStore {
    func corruptItem(
        id: String,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> SaveTransactionResult<ItemCorruptionDetail, ItemCorruptionFailure> {
        persistTransaction(logging: "Failed to corrupt item \(id)") { save in
            ItemCorruptionApplier.corrupt(itemID: id, save: &save, using: &randomNumberGenerator)
        }
    }
}
