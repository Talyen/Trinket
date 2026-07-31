import Foundation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Shared battle victory persist + dismiss used by the Play shell.
///
/// Mode owners supply only mode-unique save writes (and journey map-scroll focus).
/// Origin resolution and the post-persist dismiss sequence live here.
@MainActor
struct PlayBattleCompletion {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime
    let journey: JourneyPlayMode
    let labyrinth: LabyrinthPlayMode
    let spires: SpiresPlayMode

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    func completeActiveBattle(
        _ configuration: ActiveBattleConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil,
        queueReturnToOrigin: (PlayBattleOrigin?) -> Void
    ) -> Bool {
        guard battle.lifecyclePhase == .active else { return false }

        let hero = configuration.hero.combatant
        let companion = configuration.companion.combatant
        let origin = configuration.runKey.flatMap(PlayBattleOrigin.init(runKey:))
        let persisted = persistVictory(
            for: configuration,
            origin: origin,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards
        )
        if persisted {
            queueReturnToOrigin(origin)
            battle.endBattle()
        }
        return persisted
    }

    private func persistVictory(
        for configuration: ActiveBattleConfiguration,
        origin: PlayBattleOrigin?,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?
    ) -> Bool {
        switch origin {
        case let .journey(stageID):
            guard let stage = GameContent.stage(id: stageID) else {
                appStateLogger.error(
                    "Missing stage for battle origin: \(stageID, privacy: .public)"
                )
                return false
            }
            return journey.applyBattleVictory(
                stage: stage,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        case let .spire(spireID, floorNumber):
            guard let floor = GameContent.spireFloor(spireID: spireID, floor: floorNumber) else {
                appStateLogger.error(
                    "Missing spire floor for battle origin: \(spireID.rawValue, privacy: .public)/\(floorNumber)"
                )
                return false
            }
            return spires.completeFloor(
                floor,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        case let .labyrinth(nodeID):
            return labyrinth.completeNode(
                nodeID: nodeID,
                hero: hero,
                companion: companion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: configuration.pendingRewardItem
            )
        case .none:
            return battleEarnedGold > 0 ? grantBattleEarnedGold(battleEarnedGold) : true
        }
    }

    @discardableResult
    func grantBattleEarnedGold(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        do {
            try playerSave.performBatchMutation { save in
                save.roster.grantGold(amount)
            }
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist battle gold: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
