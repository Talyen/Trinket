import TrinketContent

public extension EncounterIdentity {
    init(location: Location, save: PlayerSave) {
        let seed: UInt64 = switch location {
        case .journey: save.worldSeed
        case .labyrinth: save.labyrinth.worldSeed
        case .voyage: save.worldSeed
        }
        self.init(location: location, worldSeed: seed, generation: save.sessionGeneration)
    }

    internal func rewardLevel(in save: PlayerSave) -> Int? {
        switch location {
        case let .journey(stageID):
            guard GameContent.stage(id: stageID) != nil else { return nil }
            return CampaignRewardLevel.resolve(in: save)
        case .voyage:
            return ContractsCompletion.campaignRewardLevel(in: save)
        case let .labyrinth(nodeID):
            return save.labyrinth.nodes[nodeID].map { _ in CampaignRewardLevel.resolve(in: save) }
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
        case let .voyage(runID, nodeID):
            return save.voyage.isPlayable(runID: runID, nodeID: nodeID)
        case let .labyrinth(nodeID):
            guard let node = save.labyrinth.nodes[nodeID] else { return false }
            return !node.isCleared && save.labyrinth.isNodeReachable(nodeID)
        }
    }
}

public extension EncounterIdentity {
    func modifierEffects(in save: PlayerSave) -> LabyrinthModifierEffects {
        switch location {
        case .journey: .zero
        case let .labyrinth(nodeID): save.labyrinth.effects(for: nodeID)
        case let .voyage(runID, nodeID): save.voyage.node(runID: runID, nodeID: nodeID)?.effects ?? .zero
        }
    }

    internal func encounterLevel(stage: Stage, in save: PlayerSave) -> Int {
        if case let .voyage(runID, _) = location, let run = save.voyage.activeRun, run.id == runID {
            return run.offer.difficulty.encounterLevel(partyLevel: save.roster.activePartyAverageLevel)
        }
        return MysteryEffectApplier.resolvedEncounterLevel(stage: stage, labyrinthNodeID: labyrinthNodeID, save: save)
    }
}
