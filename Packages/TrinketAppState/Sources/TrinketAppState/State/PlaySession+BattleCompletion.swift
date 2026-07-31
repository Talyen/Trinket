import Foundation
import TrinketBattleRuntime
import TrinketCore
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
        presentation: PlayBattlePresentationContext?,
        queueReturnToOrigin: (PlayBattleOrigin?) -> Void
    ) -> Bool {
        guard battle.lifecyclePhase == .active else { return false }

        guard (configuration.runKey == nil && route == nil)
            || route?.origin.runKey == configuration.runKey
        else {
            appStateLogger.error("Missing route for active battle completion")
            return false
        }

        let origin = route?.origin
        let persisted = if let route {
            route.complete(configuration, presentation, battleEarnedGold, materialRewards)
        } else {
            battleEarnedGold > 0 ? grantBattleEarnedGold(battleEarnedGold) : true
        }
        if persisted {
            queueReturnToOrigin(origin)
            battle.endBattle()
        }
        return persisted
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
