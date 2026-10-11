import Foundation
import SwiftData
import TrinketContent

@Model
final class LabyrinthProgressModel {
    var root: PlayerSaveRoot?
    var worldSeed: UInt64 = 0
    var mapVersion: Int = LabyrinthGenerator.currentMapVersion
    var hasEntered: Bool = false
    var mapPayload: Data?

    init() {}
}

struct LabyrinthMapPayload: Codable, Equatable {
    var clusters: [LabyrinthCluster]
    var nodes: [LabyrinthNode]
}
