import TrinketContent
import TrinketPersistence

public enum PlayEncounterOrigin: Hashable, Sendable {
    case journey(stage: Stage)
    case labyrinth(nodeID: String)

    func identity(in save: PlayerSave) -> EncounterIdentity {
        let location: EncounterIdentity.Location = switch self {
        case let .journey(stage): .journey(stageID: stage.id)
        case let .labyrinth(nodeID): .labyrinth(nodeID: nodeID)
        }
        return EncounterIdentity(location: location, save: save)
    }

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
