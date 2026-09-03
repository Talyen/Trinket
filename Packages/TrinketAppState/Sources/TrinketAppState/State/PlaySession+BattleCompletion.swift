import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
struct PlayBattleCompletion {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime

    @discardableResult
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        onPersisted: () -> Void,
        queueReturnToOrigin: (PlayBattleOrigin?) -> Void,
    ) -> Bool {
        guard battle.lifecyclePhase == .active else { return false }

        guard PlayBattleRoute.matches(
            route,
            runKey: configuration.runKey,
            missingLog: "Missing route for active battle completion",
        ) else {
            return false
        }

        guard route == nil || presentation != nil else {
            appStateLogger.error("Missing presentation metadata for active battle completion")
            return false
        }

        let origin = route?.origin
        let loot = Self.preparedLoot(
            from: presentation,
            materialRewards: materialRewards,
        )
        let persisted = if let route {
            route.complete(configuration, presentation, battleEarnedGold, materialRewards, loot)
        } else {
            battleEarnedGold != 0 ? grantBattleEarnedGold(battleEarnedGold) : true
        }
        if persisted {
            onPersisted()
            queueReturnToOrigin(origin)
            battle.endBattle()
        }
        return persisted
    }

    static func preparedLoot(
        from presentation: BattlePresentationContext?,
        materialRewards: [ResourceAmount]?,
    ) -> BattleLootResult? {
        guard let presentation, let item = presentation.pendingRewardItem else { return nil }
        return BattleLootResult(
            item: item,
            gold: presentation.stageReward?.gold ?? 0,
            materials: materialRewards ?? presentation.materialRewards,
        )
    }

    @discardableResult
    func grantBattleEarnedGold(_ amount: Int) -> Bool {
        playerSave.persistBatch(logging: "Failed to persist battle gold") { save in
            save.applyGoldDelta(amount)
        }
    }
}
