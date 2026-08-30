import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence

public extension LabyrinthMapPresentation {
    static func floorNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState,
    ) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }.sorted {
            LabyrinthGridPosition.isOrderedBefore(
                $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1),
                $1.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1),
            )
        }
    }

    static func state(
        for node: LabyrinthNode,
        in labyrinth: PlayerLabyrinthState,
    ) -> LabyrinthMapNodeState {
        if node.isCleared {
            return .cleared
        }
        return labyrinth.isNodeReachable(node.id) ? .reachable : .locked
    }
}
