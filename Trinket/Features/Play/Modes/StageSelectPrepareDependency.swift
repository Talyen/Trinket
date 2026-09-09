import TrinketContent
import TrinketPersistence

@MainActor
struct StageSelectPrepareDependency: Equatable {
    let runKey: String
    let contentAccess: ContentAccessPolicy
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64
    let stageRewardsAlreadyClaimed: Bool

    static func journey(playerSave: PlayerSaveStore) -> Self? {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat
        else { return nil }
        return Self(
            runKey: stageID,
            playerSave: playerSave,
            stageRewardsAlreadyClaimed: playerSave.journey.hasClaimedRewards(for: stage),
        )
    }

    static func spire(spireID: SpireID, floor: Int, playerSave: PlayerSaveStore) -> Self {
        Self(runKey: "\(spireID.rawValue)|\(floor)", playerSave: playerSave)
    }

    static func labyrinth(playerSave: PlayerSaveStore) -> Self {
        let labyrinth = playerSave.labyrinth
        let runKey = labyrinth.reachableNodeIDs().compactMap { nodeID -> String? in
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return nil }
            return "\(nodeID)|\(node.modifierIDs.map(\.rawValue).joined(separator: ","))"
        }
        .sorted()
        .joined(separator: ";")
        return Self(runKey: runKey, playerSave: playerSave)
    }

    private init(
        runKey: String,
        playerSave: PlayerSaveStore,
        stageRewardsAlreadyClaimed: Bool = false,
    ) {
        self.runKey = runKey
        contentAccess = playerSave.contentAccess
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
    }
}
