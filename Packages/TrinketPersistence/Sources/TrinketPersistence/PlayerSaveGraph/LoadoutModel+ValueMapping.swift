import SwiftData
import TrinketContent
import TrinketCore

extension EquipmentLoadoutModel {
    func toEquipmentLoadout() -> EquipmentLoadout {
        EquipmentLoadout(itemIDsBySlot: Dictionary(
            (slots ?? []).compactMap { slot in
                ItemSlot(rawValue: slot.slotID).map { ($0, slot.itemID) }
            },
            uniquingKeysWith: { _, new in new },
        ))
    }

    func update(from loadout: EquipmentLoadout, context: ModelContext?) {
        let values = loadout.itemIDsBySlot.sorted { $0.key.rawValue < $1.key.rawValue }
        slots = reconcileModels(
            existing: slots ?? [],
            values: values,
            existingKey: \.slotID,
            valueKey: { $0.key.rawValue },
            make: { EquipmentSlotModel() },
            update: { model, value in
                model.slotID = value.key.rawValue
                model.itemID = value.value
            },
            link: { $0.loadout = self },
            context: context,
        )
    }
}

extension TalentLoadoutModel {
    var unlockedNodeIDs: Set<String> {
        Set((unlockedNodes ?? []).map(\.nodeID))
    }

    func update(from nodeIDs: [String], context: ModelContext?) {
        unlockedNodes = reconcileModels(
            existing: unlockedNodes ?? [],
            values: nodeIDs,
            existingKey: \.nodeID,
            valueKey: { $0 },
            make: { TalentNodeUnlockModel() },
            update: { model, nodeID in
                model.nodeID = nodeID
            },
            link: { $0.loadout = self },
            context: context,
        )
    }
}
