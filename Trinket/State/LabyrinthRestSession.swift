import Foundation

/// Thin shrine rest encounter for The Labyrinth.
@MainActor
@Observable
final class LabyrinthRestSession: Identifiable {
    nonisolated let id = UUID()
    let nodeID: String
    let goldCrumb: Int
    let depth: Int
    private(set) var failureMessage: String?

    init(nodeID: String, goldCrumb: Int, depth: Int) {
        self.nodeID = nodeID
        self.goldCrumb = goldCrumb
        self.depth = depth
    }

    func markFailed(_ message: String) {
        failureMessage = message
    }

    func clearFailure() {
        failureMessage = nil
    }
}
