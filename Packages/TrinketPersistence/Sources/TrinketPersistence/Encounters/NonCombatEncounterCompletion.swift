import TrinketContent

/// Advances a saved noncombat encounter under its original identity. Pooled
/// Mystery offers have already paid their rewards and only advance progress.
enum NonCombatEncounterCompletion {
    @discardableResult
    static func complete(
        encounter: EncounterIdentity,
        grantingEncounterRewards: Bool = true,
        save: inout PlayerSave,
        access: ContentAccessPolicy = .fullGame,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> EncounterCompletion {
        guard encounter.isPlayable(in: save) else { return .unavailable }

        switch encounter.location {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID), !stage.encounter.isCombat else { return .unavailable }
            if grantingEncounterRewards {
                return StageCompletion.complete(
                    stage, hero: save.roster.activeHero, companion: save.roster.activeCompanion,
                    in: GameContent.chapters, save: &save, recordReceipt: recordReceipt,
                )
            }
            save.journey.markRewardsClaimed(for: stage)
            save.journey.complete(stage, in: GameContent.chapters)
        case let .labyrinth(nodeID):
            guard let node = save.labyrinth.node(id: nodeID), !node.type.isCombat, node.type != .entrance else { return .unavailable }
            if grantingEncounterRewards {
                return LabyrinthCompletion.complete(
                    nodeID: nodeID, hero: save.roster.activeHero, companion: save.roster.activeCompanion,
                    save: &save, access: access, recordReceipt: recordReceipt,
                )
            }
            save.labyrinth.markCleared(
                nodeID: nodeID, eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: access),
            )
        case let .voyage(runID, nodeID):
            guard VoyageCompletion.completeNode(runID: runID, nodeID: nodeID, save: &save) else { return .unavailable }
        }
        return .completed
    }
}
