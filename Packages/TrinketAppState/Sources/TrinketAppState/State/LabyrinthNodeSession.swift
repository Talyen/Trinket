import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

/// Thin Labyrinth non-combat node encounter (shrine rest or crafting altar).
@MainActor
@Observable
public final class LabyrinthNodeSession: Identifiable {
    public enum Kind: Equatable {
        case rest
        case craft
    }

    // swiftformat:disable:next modifierOrder -- SwiftLint requires isolation before access.
    nonisolated public let id = UUID()
    public let kind: Kind
    public let nodeID: String
    /// Rest: gold crumb grant preview. Craft: forge cost.
    public let goldAmount: Int
    public let depth: Int
    public private(set) var failureMessage: String?

    public init(kind: Kind, nodeID: String, goldAmount: Int, depth: Int) {
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

    static func rest(
        node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        homestead: PlayerHomesteadState
    ) -> LabyrinthNodeSession {
        let rewardGold = LabyrinthCompletion.nonCombatGoldStipend(for: node, effects: effects)
        return LabyrinthNodeSession(
            kind: .rest,
            nodeID: node.id,
            goldAmount: homestead.effects.adjustedGold(rewardGold),
            depth: node.depth
        )
    }

    static func craft(node: LabyrinthNode) -> LabyrinthNodeSession {
        LabyrinthNodeSession(
            kind: .craft,
            nodeID: node.id,
            goldAmount: LabyrinthCompletion.craftAltarCost(for: node),
            depth: node.depth
        )
    }
}
