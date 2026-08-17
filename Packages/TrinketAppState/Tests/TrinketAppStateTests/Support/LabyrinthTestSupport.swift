import TrinketContent
import TrinketPersistence
@testable import TrinketAppState

@MainActor
enum LabyrinthTestSupport {
    private static let maximumAdvanceCount = 24

    static func firstReachableCombatNodeID(in state: PlaySession) -> String? {
        firstReachableNodeID(where: { $0.type.isCombat }, in: state)
    }

    static func firstReachableNodeID(
        of type: LabyrinthNodeType,
        in state: PlaySession
    ) -> String? {
        if let existing = firstReachableNodeID(where: { $0.type.canonical == type.canonical }, in: state) {
            return existing
        }
        // Fallback: adapt an eligible uncompleted reachable node to ensure test determinism.
        let reachableIDs = state.playerSave.labyrinth.reachableNodeIDs()
        guard let targetID = reachableIDs.first(where: { id in
            guard let node = state.playerSave.labyrinth.node(id: id) else { return false }
            return !node.isCleared && node.type.canonical != .boss && node.type.canonical != .entrance
        }) ?? reachableIDs.first else {
            return nil
        }
        guard let existingNode = state.playerSave.labyrinth.node(id: targetID) else { return nil }
        let enemyID = type.isCombat ? "goblin_scout" : nil
        let modifierIDs: [LabyrinthModifierID] = switch type.canonical {
        case .shop: [LabyrinthModifierID("gildedWhisper")]
        case .craft: [LabyrinthModifierID("astralSeam")]
        default: []
        }
        let updatedNode = LabyrinthNode(
            id: existingNode.id,
            type: type,
            enemyID: enemyID,
            depth: existingNode.depth,
            clusterID: existingNode.clusterID,
            gridPosition: existingNode.gridPosition,
            modifierIDs: modifierIDs,
            recruitEventID: nil,
            mysteryEventID: nil,
            outgoingIDs: existingNode.outgoingIDs,
            isCleared: existingNode.isCleared,
            isRevealed: existingNode.isRevealed
        )
        var labyrinth = state.playerSave.labyrinth
        labyrinth.nodes[targetID] = updatedNode
        state.playerSave.labyrinth = labyrinth
        return targetID
    }

    private static func firstReachableNodeID(
        where matches: (LabyrinthNode) -> Bool,
        in state: PlaySession
    ) -> String? {
        for _ in 0 ..< maximumAdvanceCount {
            let reachableNodeIDs = state.playerSave.labyrinth.reachableNodeIDs()
            if let matchID = reachableNodeIDs.first(where: { id in
                guard let node = state.playerSave.labyrinth.node(id: id) else { return false }
                return matches(node)
            }) {
                return matchID
            }
            let candidate = reachableNodeIDs.first(where: { id in
                guard let node = state.playerSave.labyrinth.node(id: id) else { return false }
                return !node.isCleared && node.type.canonical != .boss
            }) ?? reachableNodeIDs.first
            guard let next = candidate,
                  state.labyrinth.completeNode(nodeID: next)
            else { return nil }
        }
        return nil
    }
}
