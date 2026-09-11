import Foundation
import TrinketCore

public extension GameContent {
    static var spires: [SpireDefinition] {
        SpireCatalog.spires
    }

    static func spire(id: SpireID) -> SpireDefinition? {
        SpireCatalog.spire(id: id)
    }

    static func spireFloors(for spireID: SpireID) -> [SpireFloor] {
        SpireCatalog.floors(for: spireID)
    }

    static func spireFloor(spireID: SpireID, floor: Int) -> SpireFloor? {
        SpireCatalog.floor(spireID: spireID, floor: floor)
    }
}
