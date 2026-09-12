public struct EncounterIdentity: Hashable, Codable, Sendable {
    public enum Location: Hashable, Codable, Sendable {
        case journey(stageID: String)
        case labyrinth(nodeID: String)
    }

    public let location: Location
    public let worldSeed: UInt64
    public let generation: UInt64

    public init(location: Location, worldSeed: UInt64, generation: UInt64) {
        self.location = location
        self.worldSeed = worldSeed
        self.generation = generation
    }

    public var stageID: String {
        switch location {
        case let .journey(stageID): stageID
        case let .labyrinth(nodeID): GameContent.syntheticLabyrinthStage(nodeID: nodeID, encounter: .shop).id
        }
    }

    public var labyrinthNodeID: String? {
        if case let .labyrinth(nodeID) = location {
            return nodeID
        }
        return nil
    }
}
