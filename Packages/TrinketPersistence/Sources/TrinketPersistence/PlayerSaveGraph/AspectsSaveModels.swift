import Foundation
import SwiftData

@Model
public final class AspectsProgressModel {
    public var root: PlayerSaveRoot?
    @Relationship(deleteRule: .cascade, inverse: \AspectFloorProgressModel.aspects)
    public var floors: [AspectFloorProgressModel]?

    public init() {}
}

@Model
public final class AspectFloorProgressModel {
    public var aspectID: String = ""
    public var highestClearedFloor: Int = 0
    public var aspects: AspectsProgressModel?

    public init(aspectID: String = "", highestClearedFloor: Int = 0) {
        self.aspectID = aspectID
        self.highestClearedFloor = highestClearedFloor
    }
}
