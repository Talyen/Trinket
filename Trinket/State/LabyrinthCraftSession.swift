import Foundation
import TrinketContent

/// Thin Crafting Altar encounter for The Labyrinth (gold → generated item).
@MainActor
@Observable
final class LabyrinthCraftSession: Identifiable {
    nonisolated let id = UUID()
    let nodeID: String
    let goldCost: Int
    let depth: Int
    private(set) var failureMessage: String?

    init(nodeID: String, goldCost: Int, depth: Int) {
        self.nodeID = nodeID
        self.goldCost = goldCost
        self.depth = depth
    }

    func markFailed(_ message: String) {
        failureMessage = message
    }

    func clearFailure() {
        failureMessage = nil
    }
}
