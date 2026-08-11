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
        firstReachableNodeID(where: { $0.type == type }, in: state)
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
            guard let next = reachableNodeIDs.first,
                  state.labyrinth.completeNode(nodeID: next)
            else { return nil }
        }
        return nil
    }
}
