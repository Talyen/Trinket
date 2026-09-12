import TrinketContent

public extension EncounterIdentity {
    init(location: Location, save: PlayerSave) {
        let seed: UInt64 = switch location {
        case .journey: save.worldSeed
        case .labyrinth: save.labyrinth.worldSeed
        }
        self.init(location: location, worldSeed: seed, generation: save.sessionGeneration)
    }

    internal func rewardLevel(in save: PlayerSave) -> Int? {
        switch location {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID) else { return nil }
            return StageCompletion.resolvedEncounterLevel(for: stage, in: GameContent.chapters)
        case let .labyrinth(nodeID):
            return save.labyrinth.nodes[nodeID].map { EncounterLevelResolver.labyrinthEnemyLevel(for: $0) }
        }
    }

    func isCurrent(in save: PlayerSave) -> Bool {
        self == Self(location: location, save: save)
    }

    func isPlayable(in save: PlayerSave) -> Bool {
        guard isCurrent(in: save) else { return false }
        switch location {
        case let .journey(stageID):
            return GameContent.stage(id: stageID) != nil && !save.journey.completedStageIDs.contains(stageID)
        case let .labyrinth(nodeID):
            guard let node = save.labyrinth.nodes[nodeID] else { return false }
            return !node.isCleared && save.labyrinth.isNodeReachable(nodeID)
        }
    }
}
