import BattleEngine
import Foundation
import TrinketCore
import TrinketFeatureContracts

/// Prepared simulations and the selection shown before a battle starts.
struct PreparedBattleRuns {
    struct Run {
        let configuration: BattleRunConfiguration
        let state: BattleState
    }

    private var runsByKey: [BattleRunKey: Run] = [:]
    private(set) var preferredKey: BattleRunKey?
    private(set) var revision = 0

    var isEmpty: Bool {
        runsByKey.isEmpty
    }

    var runs: [Run] {
        Array(runsByKey.values)
    }

    var selected: Run? {
        if let preferredKey, let run = runsByKey[preferredKey] {
            return run
        }
        guard runsByKey.count == 1 else { return nil }
        return runsByKey.values.first
    }

    func run(for key: BattleRunKey) -> Run? {
        runsByKey[key]
    }

    func matches(_ key: BattleRunKey, configurationID: UUID) -> Run? {
        guard let run = runsByKey[key], run.configuration.id == configurationID else { return nil }
        return run
    }

    @discardableResult
    mutating func setPreferredKey(_ key: BattleRunKey?) -> Bool {
        guard preferredKey != key else { return false }
        preferredKey = key
        revision += 1
        return true
    }

    /// Build a simulation only when this key does not already hold the same configuration.
    @discardableResult
    mutating func prepare(
        _ configuration: BattleRunConfiguration,
        for key: BattleRunKey,
        makeState: () -> BattleState,
    ) -> Bool {
        guard runsByKey[key]?.configuration.id != configuration.id else { return false }
        runsByKey[key] = Run(configuration: configuration, state: makeState())
        revision += 1
        return true
    }

    @discardableResult
    mutating func retain(_ keys: Set<BattleRunKey>) -> Bool {
        let previousCount = runsByKey.count
        runsByKey = runsByKey.filter { keys.contains($0.key) }
        let preferredWasPruned = preferredKey.map { runsByKey[$0] == nil } ?? false
        guard runsByKey.count != previousCount || preferredWasPruned else { return false }
        if preferredWasPruned {
            preferredKey = nil
        }
        revision += 1
        return true
    }

    /// Activation changes the display owner to the active battle, so it needs no prepared revision.
    mutating func removeActivated(_ key: BattleRunKey) {
        runsByKey.removeValue(forKey: key)
    }

    mutating func discardForActiveBattle() {
        runsByKey.removeAll(keepingCapacity: true)
    }

    mutating func clearForEnd() {
        guard !runsByKey.isEmpty || preferredKey != nil else { return }
        runsByKey.removeAll(keepingCapacity: true)
        preferredKey = nil
        revision += 1
    }
}
