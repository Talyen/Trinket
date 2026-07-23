import Foundation
import SwiftData

@Model
public final class SpiresProgressModel {
    public var root: PlayerSaveRoot?
    @Relationship(deleteRule: .cascade, inverse: \SpireFloorProgressModel.spires)
    public var floors: [SpireFloorProgressModel]?

    public init() {}
}

@Model
public final class SpireFloorProgressModel {
    public var spireID: String = ""
    public var highestClearedFloor: Int = 0
    public var spires: SpiresProgressModel?

    public init(spireID: String = "", highestClearedFloor: Int = 0) {
        self.spireID = spireID
        self.highestClearedFloor = highestClearedFloor
    }
}
