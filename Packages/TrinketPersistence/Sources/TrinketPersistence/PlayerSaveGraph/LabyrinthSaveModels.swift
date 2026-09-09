import Foundation
import SwiftData
import TrinketContent

@Model
public final class LabyrinthProgressModel {
    public var root: PlayerSaveRoot?
    public var worldSeed: UInt64 = 0
    public var mapVersion: Int = 1
    public var hasEntered: Bool = false
    public var mapPayload: Data?

    public init() {}
}

struct LabyrinthMapPayload: Codable, Equatable {
    var clusters: [LabyrinthCluster]
    var nodes: [LabyrinthNode]
}
