import Foundation

/// Thin Labyrinth non-combat node encounter (shrine rest or crafting altar).
@MainActor
@Observable
final class LabyrinthNodeSession: Identifiable {
    enum Kind: Equatable {
        case rest
        case craft
    }

    nonisolated let id = UUID()
    let kind: Kind
    let nodeID: String
    /// Rest: gold crumb grant preview. Craft: forge cost.
    let goldAmount: Int
    let depth: Int
    private(set) var failureMessage: String?

    init(kind: Kind, nodeID: String, goldAmount: Int, depth: Int) {
        self.kind = kind
        self.nodeID = nodeID
        self.goldAmount = goldAmount
        self.depth = depth
    }

    func markFailed(_ message: String) {
        failureMessage = message
    }

    func clearFailure() {
        failureMessage = nil
    }
}
