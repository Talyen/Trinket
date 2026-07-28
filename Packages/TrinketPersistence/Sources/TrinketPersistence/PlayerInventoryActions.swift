import Foundation
import os
import TrinketContent

private let playerInventoryActionsLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "PlayerInventoryActions"
)

public extension PlayerSaveStore {
    /// Salvages an owned inventory item into Homestead materials.
    /// Returns `nil` when persistence fails; otherwise the applier result.
    @discardableResult
    func salvageItem(id: String) -> ItemSalvageResult? {
        var result: ItemSalvageResult = .itemNotFound
        do {
            try performBatchMutation { save in
                result = ItemSalvageApplier.salvage(itemID: id, save: &save)
            }
        } catch {
            playerInventoryActionsLogger.error(
                "Failed to salvage item \(id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        return result
    }

    /// Display name of the combatant currently wearing `itemID`, if any.
    func equippedCombatantName(for itemID: String) -> String? {
        for (combatantID, loadout) in roster.equipmentLoadouts {
            guard loadout.itemIDsBySlot.values.contains(itemID) else { continue }
            if let hero = GameContent.heroes.first(where: { $0.id == combatantID }) {
                return hero.name
            }
            if let companion = GameContent.companions.first(where: { $0.id == combatantID }) {
                return companion.name
            }
            return combatantID
        }
        return nil
    }
}
