import TrinketContent

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

    func resolvedStage(labyrinthEncounter: StageEncounter) -> Stage {
        switch self {
        case let .journey(stage):
            stage
        case let .labyrinth(nodeID):
            GameContent.syntheticLabyrinthStage(nodeID: nodeID, encounter: labyrinthEncounter)
        }
    }
}
