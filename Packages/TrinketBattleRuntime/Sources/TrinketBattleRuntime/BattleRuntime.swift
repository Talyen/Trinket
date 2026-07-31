import Foundation

/// Lifecycle phase for the battle runtime. Prepared runs are held for launch
/// prewarming; active runs own the simulation and presentation lifecycle.
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
    var activeBattle: ActiveBattleConfiguration? { get }
    var lifecyclePhase: BattleLifecyclePhase { get }
    var isSuspendedForScenePhase: Bool { get }

    @discardableResult
    func prepareBattleRun(_ configuration: ActiveBattleConfiguration) -> Bool
    func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String]
    func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool
    @discardableResult
    func activate(_ configuration: ActiveBattleConfiguration) -> Bool
    @discardableResult
    func restart(_ configuration: ActiveBattleConfiguration) -> Bool

    func endBattle()
    func setSuspendedForScenePhase(_ suspended: Bool)
    func trimMemoryFootprint(releaseBattleLog: Bool)

    /// Launch-only battle chrome hook. The runtime implementation is a no-op;
    /// BattleFeature uses it to present the deterministic UI-test victory state.
    func presentLaunchVictory()
    func prepareAllBattleCinematics()
}

/// Lightweight fallback used by app-state tests and failure recovery when the
/// presentation feature is not available. It preserves lifecycle semantics but
/// intentionally does not simulate or render a battle.
@MainActor
public final class BattleRuntimeStore: BattleRuntime {
    public private(set) var activeBattle: ActiveBattleConfiguration?
    public private(set) var lifecyclePhase: BattleLifecyclePhase = .idle

    private var preparedConfigurations: [BattleRunKey: ActiveBattleConfiguration] = [:]
    public private(set) var isSuspendedForScenePhase = false

    public init() {}

    @discardableResult
    public func prepareBattleRun(_ configuration: ActiveBattleConfiguration) -> Bool {
        guard activeBattle == nil, let runKey = configuration.runKey else { return false }
        preparedConfigurations[runKey] = configuration
        lifecyclePhase = .prepared
        return true
    }

    public func preparedAbilityArtworkNames(for _: BattleRunKey) -> [String] {
        []
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
    public func activate(_ configuration: ActiveBattleConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        installActiveBattle(configuration)
        return true
    }

    @discardableResult
    public func restart(_ configuration: ActiveBattleConfiguration) -> Bool {
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
    public func presentLaunchVictory() {}
    public func prepareAllBattleCinematics() {}

    private func installActiveBattle(_ configuration: ActiveBattleConfiguration) {
        preparedConfigurations.removeAll(keepingCapacity: true)
        activeBattle = configuration
        lifecyclePhase = .active
    }
}
