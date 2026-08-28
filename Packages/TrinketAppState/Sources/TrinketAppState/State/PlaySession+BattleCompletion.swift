import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Shared battle victory sequencing used by the Play shell.
///
/// Mode owners provide a typed completion capability at launch. This type only
/// validates the route, invokes that capability, and coordinates dismissal.
@MainActor
struct PlayBattleCompletion {
    let playerSave: PlayerSaveStore
    let battle: any BattleRuntime

    /// Persists victory rewards and ends the battle only when persistence succeeds.
    @discardableResult
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]? = nil,
        route: PlayBattleRoute?,
        presentation: BattlePresentationContext?,
        onPersisted: () -> Void,
        queueReturnToOrigin: (PlayBattleOrigin?) -> Void
    ) -> Bool {
        guard battle.lifecyclePhase == .active else { return false }

        guard PlayBattleRoute.matches(
            route,
            runKey: configuration.runKey,
            missingLog: "Missing route for active battle completion"
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
            materialRewards: materialRewards
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

    /// Rebuilds the launch-baked loot package so claim grants the gold, item, and
    /// materials victory chrome already showed. Auto-claim has no materials
    /// argument; Continue may pass the same list from the summary.
    static func preparedLoot(
        from presentation: BattlePresentationContext?,
        materialRewards: [ResourceAmount]?
    ) -> BattleLootPackage? {
        guard let presentation, let item = presentation.pendingRewardItem else { return nil }
        return BattleLootPackage(
            item: item,
            gold: presentation.stageReward?.gold ?? 0,
            materials: materialRewards ?? presentation.materialRewards
        )
    }

    @discardableResult
    func grantBattleEarnedGold(_ amount: Int) -> Bool {
        playerSave.persistBatch(logging: "Failed to persist battle gold") { save in
            save.applyGoldDelta(amount)
        }
    }
}
