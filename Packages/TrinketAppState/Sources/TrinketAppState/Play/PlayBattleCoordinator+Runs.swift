import BattleEngine
import Foundation
import TrinketFeatureContracts

extension PlayBattleCoordinator {
    struct PreparedRun {
        let registration: PlayBattleRunRegistration
        let handle: any PreparedBattleRunHandle
    }

    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        if let activeRun, activeRun.launch.configuration.runKey == runKey {
            return activeRun
        }
        guard let runKey else { return nil }
        return preparedRuns[runKey]?.registration
    }

    func prepare(_ launch: BattleLaunchAssembly, route: PlayBattleRoute) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = launch.configuration.runKey,
              PlayBattleRoute.matches(route, runKey: runKey, missingLog: "Missing route for prepared battle registration")
        else { return false }
        guard let handle = battle.createPreparedRun(launch.configuration) else {
            keepPreparedRuns(Set(preparedRuns.keys).subtracting([runKey]))
            return false
        }
        preparedRuns[runKey]?.handle.invalidate()
        preparedRuns[runKey] = PreparedRun(
            registration: PlayBattleRunRegistration(route: route, launch: launch), handle: handle,
        )
        publishPreparedPreview()
        return true
    }

    func activatePrepared(_ configuration: BattleRunConfiguration) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = configuration.runKey,
              let run = preparedRuns[runKey], run.registration.launch.configuration.id == configuration.id
        else { return false }
        guard battle.activatePreparedBattle(run.handle, presentation: run.registration.presentation) else { return false }
        activeRun = run.registration
        preparedRuns[runKey] = nil
        claimState = .unclaimed
        publishPreparedPreview()
        return true
    }

    func activateStandalone(_ launch: BattleLaunchAssembly) -> Bool {
        guard battle.lifecyclePhase != .active, launch.configuration.runKey == nil else { return false }
        guard battle.activate(launch.configuration, presentation: launch.presentation) else { return false }
        activeRun = PlayBattleRunRegistration(route: nil, launch: launch)
        discardPreparations()
        claimState = .unclaimed
        return true
    }

    func restart(_ launch: BattleLaunchAssembly, route: PlayBattleRoute?) -> Bool {
        guard battle.lifecyclePhase == .active,
              battle.activeBattle?.runKey == launch.configuration.runKey,
              PlayBattleRoute.matches(route, runKey: launch.configuration.runKey, missingLog: "Missing route for battle restart")
        else { return false }
        guard battle.restart(launch.configuration, presentation: launch.presentation) else { return false }
        activeRun = PlayBattleRunRegistration(route: route, launch: launch)
        discardPreparations()
        claimState = .unclaimed
        return true
    }

    func selectPreparedRun(_ key: BattleRunKey?) {
        guard preferredPreparedRunKey != key else { return }
        preferredPreparedRunKey = key
        publishPreparedPreview()
    }

    func publishPreparedPreview() {
        let runs = preparedRuns.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value)
        let selected = preferredPreparedRunKey.flatMap { preparedRuns[$0]?.handle }
            ?? (runs.count == 1 ? runs.first?.handle : nil)
        battle.publishPreparedPreview(BattlePreparedPreview(
            configurations: runs.map(\.registration.launch.configuration), selected: selected,
        ))
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
        guard battle.lifecyclePhase != .active else { return }
        preparedRuns = preparedRuns.filter { key, run in
            let keep = keys.contains(key) || run.registration.route.map { preserve($0.origin) } == true
            if !keep {
                run.handle.invalidate()
            }
            return keep
        }
        if let preferredPreparedRunKey, preparedRuns[preferredPreparedRunKey] == nil {
            self.preferredPreparedRunKey = nil
        }
        publishPreparedPreview()
    }

    private func discardPreparations() {
        for run in preparedRuns.values {
            run.handle.invalidate()
        }
        preparedRuns.removeAll(keepingCapacity: true)
        preferredPreparedRunKey = nil
        publishPreparedPreview()
    }

    func endBattle() {
        battle.endBattle()
        activeRun = nil
        discardPreparations()
    }
}
