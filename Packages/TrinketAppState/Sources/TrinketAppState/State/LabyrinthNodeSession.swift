import Foundation
import Observation
import TrinketContent
import TrinketPersistence

/// Thin Labyrinth shrine-rest encounter (gold crumb grant preview).
@MainActor
@Observable
public final class LabyrinthNodeSession: Identifiable {
    // swiftformat:disable:next modifierOrder -- SwiftLint requires isolation before access.
    nonisolated public let id = UUID()
    public let nodeID: String
    /// Gold crumb grant preview.
    public let goldAmount: Int
    public let depth: Int
    public private(set) var failureMessage: String?

    public init(nodeID: String, goldAmount: Int, depth: Int) {
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

    static func rest(
        node: LabyrinthNode,
        homestead: PlayerHomesteadState
    ) -> LabyrinthNodeSession {
        let rewardGold = LabyrinthCompletion.nonCombatGoldStipend(for: node)
        return LabyrinthNodeSession(
            nodeID: node.id,
            goldAmount: homestead.effects.adjustedGold(rewardGold),
            depth: node.depth
        )
    }
}
