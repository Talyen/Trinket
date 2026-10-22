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
    enum RuntimeTransition { case installing, ending }
    var runtimeTransition: RuntimeTransition?
    var endRequestedDuringInstallation = false
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

    deinit {
        let battle = battle
        let activeBattle = activeBattle
        MainActorCleanup.perform {
            // A retained display cannot keep commanding an ownerless battle.
            // Delayed cleanup must not retire a replacement run on this runtime.
            guard let activeBattle,
                  battle.activeBattle?.id == activeBattle.registration.launch.configuration.id else { return }
            battle.endBattle()
        }
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
        guard let activeBattle else { return }
        finishBattle(activeBattle) {
            onFinished()
            reset()
        }
    }

    func isCurrent(_ run: ActivePlayBattle) -> Bool {
        activeBattle === run && battle.lifecyclePhase == .active
            && battle.activeBattle?.id == run.registration.launch.configuration.id
    }

    /// Origin restoration and runtime teardown notify observers synchronously.
    /// Consume this run's exit before either can reenter the coordinator.
    func finishBattle(_ run: ActivePlayBattle, onFinished: () -> Void) {
        guard isCurrent(run) else { return }
        if runtimeTransition == .installing {
            endBattle()
            return
        }
        guard runtimeTransition == nil else { return }
        runtimeTransition = .ending
        defer { runtimeTransition = nil }
        run.claimState = .ending
        restoreOrigin(run.registration.route?.origin)
        guard isCurrent(run) else { return }
        retireBattle()
        onFinished()
    }
}
