import Foundation
import SwiftData
import TrinketContent
import TrinketCore

extension SpiresProgressModel {
    func toPlayerSpiresState() -> PlayerSpiresState {
        let rows = floors ?? []
        var map: [String: Int] = [:]
        for row in rows where !row.spireID.isEmpty {
            map[row.spireID] = row.highestClearedFloor
        }
        return PlayerSpiresState(highestClearedFloorBySpireID: map)
    }

    func update(from state: PlayerSpiresState, context: ModelContext?) {
        let values = state.highestClearedFloorBySpireID.sorted { $0.key < $1.key }
        floors = reconcileModels(
            existing: floors ?? [],
            values: values,
            existingKey: \.spireID,
            valueKey: { $0.key },
            make: { _ in SpireFloorProgressModel() },
            update: { model, value in
                model.spireID = value.key
                model.highestClearedFloor = max(0, value.value)
            },
            link: { $0.spires = self },
            context: context,
        )
    }
}
