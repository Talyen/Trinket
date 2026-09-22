import BattleEngine
import Foundation

/// Owns app-side run lifetimes: runtime resources and route/reward metadata
/// change together. Launch chooses inputs; this owner enforces transitions.
@MainActor
final class PlayBattleRuns {
    private let battle: any BattleRuntime
    private var registrations: [BattleRunKey: PlayBattleRunRegistration] = [:]

    init(battle: any BattleRuntime) {
        self.battle = battle
    }

    func registration(for runKey: BattleRunKey?) -> PlayBattleRunRegistration? {
        guard let runKey else { return nil }
        return registrations[runKey]
    }

    func prepare(_ launch: BattleLaunchAssembly, route: PlayBattleRoute) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = launch.configuration.runKey,
              PlayBattleRoute.matches(
                  route, runKey: runKey,
                  missingLog: "Missing route for prepared battle registration",
              ) else { return false }
        guard battle.prepareBattleRun(launch.configuration) else {
            // A rejected refresh invalidates only its own run. Other modes'
            // preparations and their original RNG remain available.
            keepPreparedRuns(Set(registrations.keys).subtracting([runKey]))
            return false
        }
        registrations[runKey] = PlayBattleRunRegistration(route: route, launch: launch)
        return true
    }

    func activatePrepared(_ configuration: BattleRunConfiguration) -> Bool {
        guard battle.lifecyclePhase != .active,
              let runKey = configuration.runKey,
              registrations[runKey]?.launch.configuration.id == configuration.id
        else { return false }
        // Rejection retains both halves so the same preparation can be retried.
        return battle.activatePreparedBattle(runKey: runKey, configurationID: configuration.id)
    }

    func activateStandalone(_ configuration: BattleRunConfiguration) -> Bool {
        guard battle.lifecyclePhase != .active, configuration.runKey == nil,
              battle.activate(configuration) else { return false }
        registrations.removeAll(keepingCapacity: true)
        return true
    }

    func restart(_ launch: BattleLaunchAssembly, route: PlayBattleRoute?) -> Bool {
        guard battle.lifecyclePhase == .active,
              battle.activeBattle?.runKey == launch.configuration.runKey,
              PlayBattleRoute.matches(
                  route, runKey: launch.configuration.runKey,
                  missingLog: "Missing route for battle restart",
              ) else { return false }
        let runKey = launch.configuration.runKey
        let previous = registration(for: runKey)
        if let runKey, let route {
            // Runtime activation synchronously resolves this presentation.
            registrations[runKey] = PlayBattleRunRegistration(route: route, launch: launch)
        }
        guard battle.restart(launch.configuration) else {
            if let runKey {
                registrations[runKey] = previous
            }
            return false
        }
        // Runtime restart clears all preparations; only the active route remains.
        registrations = registrations.filter { $0.key == runKey }
        return true
    }

    func keepPreparedRuns(
        _ keys: Set<BattleRunKey>,
        preservingWhere preserve: (PlayBattleOrigin) -> Bool = { _ in false },
    ) {
        guard battle.lifecyclePhase != .active else { return }
        let preserved = registrations.filter { preserve($0.value.route.origin) }.keys
        let survivors = keys.union(preserved)
        battle.keepPreparedRuns(survivors)
        registrations = registrations.filter { survivors.contains($0.key) }
    }

    func endBattle() {
        battle.endBattle()
        registrations.removeAll(keepingCapacity: true)
    }
}
