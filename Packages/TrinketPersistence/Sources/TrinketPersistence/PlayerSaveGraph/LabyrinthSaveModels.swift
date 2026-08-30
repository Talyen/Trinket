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
    var runHealthByCombatantID: [String: Int] = [:]

    init(
        clusters: [LabyrinthCluster],
        nodes: [LabyrinthNode],
        runHealthByCombatantID: [String: Int] = [:],
    ) {
        self.clusters = clusters
        self.nodes = nodes
        self.runHealthByCombatantID = runHealthByCombatantID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clusters = try container.decode([LabyrinthCluster].self, forKey: .clusters)
        nodes = try container.decode([LabyrinthNode].self, forKey: .nodes)
        runHealthByCombatantID = try container.decodeIfPresent(
            [String: Int].self,
            forKey: .runHealthByCombatantID,
        ) ?? [:]
    }
}
