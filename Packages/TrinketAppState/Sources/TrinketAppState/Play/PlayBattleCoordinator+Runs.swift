import BattleEngine
import Foundation
import TrinketFeatureContracts

extension PlayBattleCoordinator {
    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        if let activeRun, activeRun.launch.configuration.runKey == runKey {
            return activeRun
        }
        guard let runKey else { return nil }
        return preparedRuns[runKey]?.registration
    }

    func prepare(_ launch: BattleLaunchAssembly, route: PlayBattleRoute) -> Bool {
        guard runtimeTransition == nil, battle.lifecyclePhase != .active,
              let runKey = launch.configuration.runKey,
              PlayBattleRoute.matches(route, runKey: runKey, missingLog: "Missing route for prepared battle registration")
        else { return false }
        if let run = preparedRuns[runKey],
           run.registration.launch.configuration.id == launch.configuration.id,
           run.registration.rewardClaim.isCurrent(in: playerSave) {
            // Refresh application metadata without tearing down the simulation or
            // its preview. Activation receives this current presentation explicitly.
            preparations.install(.init(
                registration: makeRegistration(launch, route: route), handle: run.handle,
            ), for: runKey)
            return true
        }
        guard let handle = battle.createPreparedRun(launch.configuration) else {
            keepPreparedRuns(Set(preparedRuns.keys).subtracting([runKey]))
            return false
        }
        preparations.install(.init(
            registration: makeRegistration(launch, route: route), handle: handle,
        ), for: runKey)
        publishPreparedPreview()
        return true
    }

    func activatePrepared(_ configuration: BattleRunConfiguration) -> Bool {
        guard runtimeTransition == nil, battle.lifecyclePhase != .active,
              let runKey = configuration.runKey,
              let run = preparedRuns[runKey], run.registration.launch.configuration.id == configuration.id,
              run.registration.rewardClaim.isCurrent(in: playerSave)
        else { return false }
        return installRuntime {
            guard battle.activatePreparedBattle(run.handle, presentation: run.registration.presentation) else { return false }
            activeBattle = ActivePlayBattle(run.registration)
            preparations.consume(runKey)
            publishPreparedPreview()
            return true
        }
    }

    func activateStandalone(_ launch: BattleLaunchAssembly) -> Bool {
        guard battle.lifecyclePhase != .active, launch.configuration.runKey == nil else { return false }
        return installRuntime {
            guard battle.activate(launch.configuration, presentation: launch.presentation) else { return false }
            activeBattle = ActivePlayBattle(makeRegistration(launch, route: nil))
            discardPreparations()
            return true
        }
    }

    func restart(_ launch: BattleLaunchAssembly, route: PlayBattleRoute?) -> Bool {
        guard battle.lifecyclePhase == .active, activeBattle?.canRestart == true,
              battle.activeBattle?.runKey == launch.configuration.runKey,
              activeRun?.rewardClaim.isCurrent(in: playerSave) == true,
              PlayBattleRoute.matches(route, runKey: launch.configuration.runKey, missingLog: "Missing route for battle restart")
        else { return false }
        return installRuntime {
            guard battle.restart(launch.configuration, presentation: launch.presentation) else { return false }
            activeBattle = ActivePlayBattle(makeRegistration(launch, route: route))
            discardPreparations()
            return true
        }
    }

    func selectPreparedRun(_ key: BattleRunKey?) {
        guard runtimeTransition == nil, preparations.select(key) else { return }
        publishPreparedPreview()
    }

    private func makeRegistration(_ launch: BattleLaunchAssembly, route: PlayBattleRoute?) -> PlayBattleRunRegistration {
        PlayBattleRunRegistration(
            route: route, launch: launch,
            rewardClaim: playerSave.prepareBattleRewardClaim(
                at: route, heroID: launch.configuration.hero.combatant.id,
                companionID: launch.configuration.companion.combatant.id,
            ),
        )
    }

    func publishPreparedPreview() {
        battle.publishPreparedPreview(preparations.preview)
    }

    /// Pruning belongs to the application registry; sibling modes retain their handles.
    func prunePreparedRuns(for mode: PlayBattleMode, keeping keys: Set<BattleRunKey> = []) {
        keepPreparedRuns(keys, preservingWhere: { $0.mode != mode })
    }

    func pruneAllPreparedRuns() {
        keepPreparedRuns([])
    }

    func keepPreparedRuns(
        _ keys: Set<BattleRunKey>,
        preservingWhere preserve: (PlayBattleOrigin) -> Bool = { _ in false },
    ) {
        guard runtimeTransition == nil, battle.lifecyclePhase != .active else { return }
        preparations.retain { key, run in
            keys.contains(key) || run.registration.route.map { preserve($0.origin) } == true
        }
        publishPreparedPreview()
    }

    private func discardPreparations() {
        preparations.retain { _, _ in false }
        publishPreparedPreview()
    }

    private func installRuntime(_ install: () -> Bool) -> Bool {
        guard runtimeTransition == nil else { return false }
        runtimeTransition = .installing
        let installed = install()
        runtimeTransition = nil
        if endRequestedDuringInstallation {
            endRequestedDuringInstallation = false
            endBattle()
            return false
        }
        return installed
    }

    func endBattle() {
        if runtimeTransition == .installing {
            endRequestedDuringInstallation = true
            return
        }
        guard runtimeTransition == nil else { return }
        runtimeTransition = .ending
        defer { runtimeTransition = nil }
        retireBattle()
    }

    func retireBattle() {
        // Revoke the registration before runtime observation can reenter claims.
        activeBattle = nil
        battle.endBattle()
        discardPreparations()
    }
}
