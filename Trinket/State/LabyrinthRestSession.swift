import Foundation
import TrinketContent

/// Thin shrine rest encounter for Wanderer's Labyrinth.
@MainActor
@Observable
final class LabyrinthRestSession: Identifiable {
    let id = UUID()
    let nodeID: String
    let goldCrumb: Int
    let depth: Int

    init(nodeID: String, goldCrumb: Int, depth: Int) {
        self.nodeID = nodeID
        self.goldCrumb = goldCrumb
        self.depth = depth
    }
}
