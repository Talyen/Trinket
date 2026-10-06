import TrinketContent

/// Saved encounter identity; presentation derives its return route separately.
public enum BattleCompletionDestination {
    case journey(Stage)
    case spire(SpireFloor)
    case labyrinth(nodeID: String, access: ContentAccessPolicy)
    case contract(offerID: String)
    case voyage(runID: String, nodeID: String, encounterLevel: Int, access: ContentAccessPolicy)
}

public enum EncounterCompletionFailure: Error {
    case unavailable
}
