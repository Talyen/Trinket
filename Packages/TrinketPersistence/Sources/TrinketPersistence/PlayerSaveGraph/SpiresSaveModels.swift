import Foundation
import SwiftData

@Model
final class SpiresProgressModel {
    var root: PlayerSaveRoot?
    @Relationship(deleteRule: .cascade, inverse: \SpireFloorProgressModel.spires)
    var floors: [SpireFloorProgressModel]?

    init() {}
}

@Model
final class SpireFloorProgressModel {
    var spireID: String = ""
    var highestClearedFloor: Int = 0
    var spires: SpiresProgressModel?

    init(spireID: String = "", highestClearedFloor: Int = 0) {
        self.spireID = spireID
        self.highestClearedFloor = highestClearedFloor
    }
}
