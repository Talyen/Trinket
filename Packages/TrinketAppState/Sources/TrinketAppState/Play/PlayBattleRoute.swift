import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Completion data for the closed set of battle modes. The same case determines
/// return navigation and the save mutation; registrations retain no mode callbacks.
@MainActor
enum PlayBattleRoute {
    case journey(Stage)
    case spire(SpireFloor)
    case labyrinth(nodeID: String, access: ContentAccessPolicy)
    case contract(offerID: String)
    case voyage(runID: String, nodeID: String, encounterLevel: Int, access: ContentAccessPolicy)

    private enum Rejection: Error {
        case unavailable
    }

    var origin: PlayBattleOrigin {
        switch self {
        case let .journey(stage): .journey(stageID: stage.id)
        case let .spire(floor): .spire(spireID: floor.spireID, floor: floor.floor)
        case let .labyrinth(nodeID, _): .labyrinth(nodeID: nodeID)
        case let .contract(offerID): .contract(offerID: offerID)
        case let .voyage(runID, nodeID, _, _): .voyage(runID: runID, nodeID: nodeID)
        }
    }

    private var failureLog: String {
        switch self {
        case .journey: "Failed to persist stage completion"
        case .spire: "Failed to persist Spire floor"
        case .labyrinth: "Failed to persist Labyrinth node"
        case .contract: "Failed to complete contract"
        case .voyage: "Failed to complete Voyage node"
        }
    }

    func complete(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        award: BattleRewardSettlement,
        materialRewards: [ResourceAmount]?,
        loot: BattleLootResult?,
        playerSave: PlayerSaveStore,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> BattleCompletionResult {
        let transaction = playerSave.persistTransaction(logging: failureLog) { save -> Result<Void, Rejection> in
            switch apply(
                configuration, presentation: presentation, award: award,
                materialRewards: materialRewards, loot: loot, save: &save, makeContractOffer: makeContractOffer,
            ) {
            case .completed: .success(())
            case .alreadyCompleted, .unavailable: .failure(.unavailable)
            }
        }
        // Rejected duplicate/stale encounters never commit a candidate. Only a
        // failed write is retryable, and it leaves the route available to retry.
        switch transaction {
        case .committed: return .completed
        case .rejected: return .unavailable
        case .persistFailed: return .persistenceFailed
        }
    }

    private func apply(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        award: BattleRewardSettlement,
        materialRewards: [ResourceAmount]?,
        loot: BattleLootResult?,
        save: inout PlayerSave,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer,
    ) -> EncounterCompletion {
        let hero = configuration.hero.combatant
        let companion = configuration.companion.combatant
        let battleGold = award.award.goldFlow
        let item = presentation.pendingRewardItem
        let level = configuration.enemyEncounterLevel
        switch self {
        case let .journey(stage):
            return StageCompletion.complete(
                stage, hero: hero, companion: companion, battleGold: battleGold, award: award,
                materialRewards: materialRewards, rewardItem: item, loot: loot, enemyEncounterLevel: level,
                in: GameContent.chapters, save: &save,
            )
        case let .spire(floor):
            return SpireCompletion.complete(
                floor: floor, hero: hero, companion: companion, battleGold: battleGold, award: award,
                materialRewards: materialRewards, rewardItem: item, loot: loot, enemyEncounterLevel: level, save: &save,
            )
        case let .labyrinth(nodeID, access):
            return LabyrinthCompletion.complete(
                nodeID: nodeID, hero: hero, companion: companion, battleGold: battleGold, award: award,
                materialRewards: materialRewards, rewardItem: item, loot: loot, enemyEncounterLevel: level,
                save: &save, access: access,
            )
        case let .contract(offerID):
            guard let loot, let level else { return .unavailable }
            return ContractsCompletion.complete(
                offerID: offerID, hero: hero, companion: companion, encounterLevel: level, loot: loot,
                battleGold: battleGold, award: award, save: &save, makeOffer: makeContractOffer,
            )
        case let .voyage(runID, nodeID, encounterLevel, access):
            let earned = presentation.rewardPlan.resolve(
                battleGold: battleGold, materials: materialRewards, includingCompletionBonus: false,
            )
            return VoyageCompletion.completeBattle(
                runID: runID, nodeID: nodeID, hero: hero, companion: companion,
                rewards: (award, earned, encounterLevel), save: &save, access: access,
            )
        }
    }

    static func matches(_ route: Self?, runKey: BattleRunKey?, missingLog: String) -> Bool {
        guard let runKey else { return route == nil }
        guard let route, route.origin.runKey == runKey else {
            appStateLogger.error("\(missingLog, privacy: .public)")
            return false
        }
        return true
    }
}
