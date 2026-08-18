import Foundation

/// Lifecycle phase for the battle runtime. Prepared runs are held for launch
/// prewarming; active runs own the simulation lifecycle.
public enum BattleLifecyclePhase: Equatable, Sendable {
    case idle
    case prepared
    case active
}

/// The app-state-facing battle lifecycle boundary.
///
/// This contract deliberately contains only run preparation, activation, and
/// lifecycle controls. BattleFeature supplies the presentation-backed implementation;
/// AppState and Play modes can therefore compile without importing that UI module.
@MainActor
public protocol BattleRuntime: AnyObject {
    var activeBattle: BattleRunConfiguration? { get }
    var lifecyclePhase: BattleLifecyclePhase { get }
    var isSuspendedForScenePhase: Bool { get }

    @discardableResult
    func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool
    func keepPreparedRuns(_ keys: Set<BattleRunKey>)
    func hasPreparedRun(_ runKey: BattleRunKey) -> Bool
    func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool
    @discardableResult
    func activate(_ configuration: BattleRunConfiguration) -> Bool
    @discardableResult
    func restart(_ configuration: BattleRunConfiguration) -> Bool

    func endBattle()
    func setSuspendedForScenePhase(_ suspended: Bool)
    func trimMemoryFootprint(releaseBattleLog: Bool)
}

/// Lightweight fallback used by app-state tests and failure recovery when the
/// presentation feature is not available. It preserves lifecycle semantics but
/// intentionally does not simulate or render a battle.
@MainActor
public final class BattleRuntimeStore: BattleRuntime {
    public private(set) var activeBattle: BattleRunConfiguration?
    public private(set) var lifecyclePhase: BattleLifecyclePhase = .idle

    private var preparedConfigurations: [BattleRunKey: BattleRunConfiguration] = [:]
    public private(set) var isSuspendedForScenePhase = false

    public init() {}

    @discardableResult
    public func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil, let runKey = configuration.runKey else { return false }
        preparedConfigurations[runKey] = configuration
        lifecyclePhase = .prepared
        return true
    }

    public func keepPreparedRuns(_ keys: Set<BattleRunKey>) {
        guard activeBattle == nil else { return }
        preparedConfigurations = preparedConfigurations.filter { keys.contains($0.key) }
        if preparedConfigurations.isEmpty {
            lifecyclePhase = .idle
        }
    }

    public func hasPreparedRun(_ runKey: BattleRunKey) -> Bool {
        preparedConfigurations[runKey] != nil
    }

    public func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let configuration = preparedConfigurations[runKey],
              configuration.hero.combatant.id == heroID,
              configuration.companion.combatant.id == companionID,
              configuration.enemy?.id == enemyID
        else { return false }
        preparedConfigurations.removeValue(forKey: runKey)
        installActiveBattle(configuration)
        return true
    }

    @discardableResult
    public func activate(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        installActiveBattle(configuration)
        return true
    }

    @discardableResult
    public func restart(_ configuration: BattleRunConfiguration) -> Bool {
        guard activeBattle != nil else { return false }
        installActiveBattle(configuration)
        return true
    }

    public func endBattle() {
        activeBattle = nil
        preparedConfigurations.removeAll(keepingCapacity: true)
        lifecyclePhase = .idle
    }

    public func setSuspendedForScenePhase(_ suspended: Bool) {
        isSuspendedForScenePhase = suspended
    }

    public func trimMemoryFootprint(releaseBattleLog _: Bool) {}

    private func installActiveBattle(_ configuration: BattleRunConfiguration) {
        preparedConfigurations.removeAll(keepingCapacity: true)
        activeBattle = configuration
        lifecyclePhase = .active
    }
}
