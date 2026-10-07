import BattleEngine
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

typealias PlayBattleRoute = BattleCompletionDestination

extension BattleCompletionDestination {
    var origin: PlayBattleOrigin {
        switch self {
        case let .journey(stage): .journey(stageID: stage.id)
        case let .spire(floor): .spire(spireID: floor.spireID, floor: floor.floor)
        case let .labyrinth(nodeID, _): .labyrinth(nodeID: nodeID)
        case let .contract(offerID): .contract(offerID: offerID)
        case let .voyage(runID, nodeID, _, _): .voyage(runID: runID, nodeID: nodeID)
        }
    }

    @MainActor
    func complete(
        _ configuration: BattleRunConfiguration,
        launch: BattleLaunchAssembly,
        award: BattleRewardSettlement,
        materialRewards: [ResourceAmount]?,
        playerSave: PlayerSaveStore,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> BattleCompletionResult {
        guard let enemyEncounterLevel = configuration.enemyEncounterLevel else { return .unavailable }
        let earnedVoyageRewards: BattleRewardAward? = if case .voyage = self {
            launch.rewardPlan.resolve(battleGold: award.award.goldFlow, materials: materialRewards, includingCompletionBonus: false)
        } else {
            nil
        }
        let result = playerSave.completeBattle(
            at: self, party: (configuration.hero.combatant, configuration.companion.combatant),
            award: award,
            enemyEncounterLevel: enemyEncounterLevel,
            earnedVoyageRewards: earnedVoyageRewards,
            makeContractOffer: makeContractOffer,
        )
        switch result {
        case .committed: return .completed
        case .rejected: return .unavailable
        case .persistFailed: return .persistenceFailed
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
