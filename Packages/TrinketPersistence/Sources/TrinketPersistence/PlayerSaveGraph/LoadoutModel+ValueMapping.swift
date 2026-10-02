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
        let values = loadout.itemIDsBySlot
            .map { (slotID: $0.key.rawValue, itemID: $0.value) }
            .sorted { $0.slotID < $1.slotID }
        slots = reconcileModels(
            existing: slots ?? [],
            values: values,
            existingKey: \.slotID,
            valueKey: { $0.slotID },
            make: { _ in EquipmentSlotModel() },
            update: { model, value in
                model.slotID = value.slotID
                model.itemID = value.itemID
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
            make: { _ in TalentNodeUnlockModel() },
            update: { model, nodeID in
                model.nodeID = nodeID
            },
            link: { $0.loadout = self },
            context: context,
        )
    }
}
