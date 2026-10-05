import BattleEngine
import Foundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Owns application battle transitions and their authoritative launch/reward data.
/// BattleRuntime retains simulation resources; presentation is a projection only.
@MainActor
final class PlayBattleCoordinator {
    struct PendingExit {
        let configurationID: UUID
        let origin: PlayBattleOrigin?
        let onFinished: () -> Void
    }

    enum ClaimState {
        case unclaimed
        case defeat(configurationID: UUID)
        case victory(PendingExit)
    }

    let playerSave: PlayerSaveStore
    let shellSession: ShellSession
    let battle: any BattleRuntime
    let battlePerformanceScenario: BattlePerformanceScenario?
    var nextCombatSeed: () -> UInt64 = { UInt64.random(in: .min ... .max) }
    var preparedRuns: [BattleRunKey: PlayBattleRunRegistration] = [:]
    var activeRun: PlayBattleRunRegistration?
    var claimState: ClaimState = .unclaimed
    var talentProgressionsBefore: [String: CombatantProgression] = [:]

    init(
        playerSave: PlayerSaveStore,
        shellSession: ShellSession,
        battle: any BattleRuntime,
        battlePerformanceScenario: BattlePerformanceScenario?,
    ) {
        self.playerSave = playerSave
        self.shellSession = shellSession
        self.battle = battle
        self.battlePerformanceScenario = battlePerformanceScenario
    }

    func restoreOrigin(_ origin: PlayBattleOrigin?) {
        if let path = PlayLaunchDestination.returnPath(from: origin) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                shellSession.playPath = path
            }
        }
        shellSession.selectedTab = .play
    }

    func endBattleReturningToOrigin(onFinished: () -> Void) {
        restoreOrigin(activeRun?.route?.origin)
        endBattle()
        onFinished()
        reset()
    }
}
