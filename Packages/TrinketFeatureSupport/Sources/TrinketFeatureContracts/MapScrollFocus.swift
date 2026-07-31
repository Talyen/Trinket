import Foundation

public struct MapScrollFocus: Equatable {
    public let stageID: String
    public let revision: UInt

    public init(stageID: String, revision: UInt) {
        self.stageID = stageID
        self.revision = revision
    }
}
