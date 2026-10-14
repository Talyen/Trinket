import BattleEngine
import Foundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Owns application battle transitions and their authoritative launch/reward data.
/// BattleRuntime retains simulation resources; presentation is a projection only.
@MainActor
final class PlayBattleCoordinator {
    let playerSave: PlayerSaveStore
    let shellSession: ShellSession
    let battle: any BattleRuntime
    let battlePerformanceScenario: BattlePerformanceScenario?
    var nextCombatSeed: () -> UInt64 = { UInt64.random(in: .min ... .max) }
    let preparations = PreparedBattleRegistry()
    var activeBattle: ActivePlayBattle?
    var preparedRuns: [BattleRunKey: PreparedBattleRegistry.Entry] {
        preparations.entries
    }

    var activeRun: PlayBattleRunRegistration? {
        activeBattle?.registration
    }

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
