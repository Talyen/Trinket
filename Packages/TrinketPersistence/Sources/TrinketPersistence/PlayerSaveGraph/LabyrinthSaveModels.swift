import Foundation
import SwiftData
import TrinketContent

@Model
public final class LabyrinthProgressModel {
    public var root: PlayerSaveRoot?
    public var worldSeed: UInt64 = 0
    public var deepestDepth: Int = 0
    public var hasEntered: Bool = false
    public var mapPayload: Data?
    public var discoveredBiomeIDs: [String] = []
    public var discoveredModifierIDs: [String] = []
    public var claimedMilestoneDepths: [Int] = []

    public init() {}
}

struct LabyrinthMapPayload: Codable, Equatable {
    var clusters: [LabyrinthCluster]
    var nodes: [LabyrinthNode]
}
