import BattleEngine
import Foundation
import TrinketBattleRuntime

/// Concrete, presentation-free owner for one battle lifecycle.
///
/// Play talks to this object through `BattleRuntime`. `BattleSession` observes
/// its change notifications and owns only feedback, spectacle, overlays, and
/// timing. Keeping the simulation and lifecycle here prevents app orchestration
/// from accidentally depending on BattleFeature's presentation state.
@MainActor
public final class BattleRuntimeSession: BattleRuntime {
    enum Change {
        case prepared
        case activated
        case ended
        case suspensionChanged(Bool)
        case memoryTrimmed(releaseBattleLog: Bool)
    }

    struct PreparedBattleRun {
        let configuration: BattleRunConfiguration
        let simulation: BattleSimulationStore.PreparedRun
    }

    /// The presentation coordinator installs this callback at the composition
    /// root. It is internal so the lifecycle contract remains closure-free.
    var onChange: (@MainActor (Change) -> Void)?

    let simulation = BattleSimulationStore()

    public private(set) var activeBattle: BattleRunConfiguration?
    public private(set) var lifecyclePhase: BattleLifecyclePhase = .idle
    public private(set) var isSuspendedForScenePhase = false
    public private(set) var preparedBattlePresentationRevision = 0

    private var preparedBattleRunsByKey: [BattleRunKey: PreparedBattleRun] = [:]

    var preparedBattleRuns: [PreparedBattleRun] {
        Array(preparedBattleRunsByKey.values)
    }

    public init() {}

    @discardableResult
    public func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil,
              let runKey = configuration.runKey
        else { return false }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return true
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            simulation: simulation.makePreparedRun(from: configuration)
        )
        preparedBattlePresentationRevision += 1
        lifecyclePhase = .prepared
        onChange?(.prepared)
        return true
    }

    func preparedBattleRun(for runKey: BattleRunKey) -> PreparedBattleRun? {
        preparedBattleRunsByKey[runKey]
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.runKey == runKey,
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }

        preparedBattleRunsByKey.removeValue(forKey: runKey)
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = preparedBattleRun.configuration
        simulation.activate(preparedBattleRun.simulation)
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    @discardableResult
    public func activate(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = configuration
        simulation.reset(from: configuration)
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    @discardableResult
    public func restart(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle != nil else { return false }
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        activeBattle = configuration
        simulation.reset(from: configuration)
        lifecyclePhase = .active
        onChange?(.activated)
        return true
    }

    public func endBattle() {
        activeBattle = nil
        preparedBattleRunsByKey.removeAll(keepingCapacity: true)
        simulation.clear()
        lifecyclePhase = .idle
        onChange?(.ended)
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        guard isSuspendedForScenePhase != suspended else { return }
        isSuspendedForScenePhase = suspended
        onChange?(.suspensionChanged(suspended))
    }

    public func trimMemoryFootprint(releaseBattleLog: Bool) {
        if releaseBattleLog {
            simulation.releaseLogProjection()
        }
        onChange?(.memoryTrimmed(releaseBattleLog: releaseBattleLog))
    }
}
