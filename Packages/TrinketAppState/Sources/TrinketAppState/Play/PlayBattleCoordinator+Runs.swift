import BattleEngine
import Foundation

extension PlayBattleCoordinator {
    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        if let activeRun, activeRun.launch.configuration.runKey == runKey {
            return activeRun
        }
        guard let runKey else { return nil }
        return preparedRuns[runKey]
    }

    func prepare(_ launch: BattleLaunchAssembly, route: PlayBattleRoute) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = launch.configuration.runKey,
              PlayBattleRoute.matches(route, runKey: runKey, missingLog: "Missing route for prepared battle registration")
        else { return false }
        guard battle.prepareBattleRun(launch.configuration) else {
            keepPreparedRuns(Set(preparedRuns.keys).subtracting([runKey]))
            return false
        }
        preparedRuns[runKey] = PlayBattleRunRegistration(route: route, launch: launch)
        return true
    }

    func activatePrepared(_ configuration: BattleRunConfiguration) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = configuration.runKey,
              let run = preparedRuns[runKey], run.launch.configuration.id == configuration.id
        else { return false }
        guard battle.activatePreparedBattle(runKey: runKey, configurationID: configuration.id) else { return false }
        activeRun = run
        preparedRuns[runKey] = nil
        claimState = .unclaimed
        return true
    }

    func activateStandalone(_ launch: BattleLaunchAssembly) -> Bool {
        guard battle.lifecyclePhase != .active, launch.configuration.runKey == nil else { return false }
        let previous = activeRun
        activeRun = PlayBattleRunRegistration(route: nil, launch: launch)
        guard battle.activate(launch.configuration) else {
            activeRun = previous
            return false
        }
        preparedRuns.removeAll(keepingCapacity: true)
        claimState = .unclaimed
        return true
    }

    func restart(_ launch: BattleLaunchAssembly, route: PlayBattleRoute?) -> Bool {
        guard battle.lifecyclePhase == .active,
              battle.activeBattle?.runKey == launch.configuration.runKey,
              PlayBattleRoute.matches(route, runKey: launch.configuration.runKey, missingLog: "Missing route for battle restart")
        else { return false }
        let previous = activeRun
        // Installation synchronously looks up the candidate's presentation.
        activeRun = PlayBattleRunRegistration(route: route, launch: launch)
        guard battle.restart(launch.configuration) else {
            activeRun = previous
            return false
        }
        preparedRuns.removeAll(keepingCapacity: true)
        claimState = .unclaimed
        return true
    }

    /// Prunes prepared battle runs belonging to a specific play mode, keeping
    /// only the specified run keys for that mode, while preserving all prepared
    /// runs belonging to sibling modes.
    func prunePreparedRuns(
        for mode: PlayBattleMode,
        keeping keys: Set<BattleRunKey> = [],
    ) {
        keepPreparedRuns(keys, preservingWhere: { $0.mode != mode })
    }

    /// Prunes all prepared battle runs across all modes.
    func pruneAllPreparedRuns() {
        keepPreparedRuns([])
    }

    func keepPreparedRuns(
        _ keys: Set<BattleRunKey>,
        preservingWhere preserve: (PlayBattleOrigin) -> Bool = { _ in false },
    ) {
        guard battle.lifecyclePhase != .active else { return }
        let preserved = preparedRuns.filter { run in
            run.value.route.map { preserve($0.origin) } ?? false
        }.keys
        let survivors = keys.union(preserved)
        battle.keepPreparedRuns(survivors)
        preparedRuns = preparedRuns.filter { survivors.contains($0.key) }
    }

    func endBattle() {
        battle.endBattle()
        activeRun = nil
        preparedRuns.removeAll(keepingCapacity: true)
    }
}
