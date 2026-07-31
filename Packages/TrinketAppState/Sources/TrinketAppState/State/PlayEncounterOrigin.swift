import TrinketContent

/// Identifies the map owner that opened a transient encounter.
///
/// The origin is intentionally a closed value instead of a pair of optional
/// parameters. An encounter is either owned by a journey stage or by one
/// Labyrinth node; there is no valid third state.
public enum PlayEncounterOrigin: Hashable, Sendable {
    case journey(stage: Stage)
    case labyrinth(nodeID: String)

    public var stage: Stage? {
        if case let .journey(stage) = self {
            return stage
        }
        return nil
    }

    public var labyrinthNodeID: String? {
        if case let .labyrinth(nodeID) = self {
            return nodeID
        }
        return nil
    }
}
