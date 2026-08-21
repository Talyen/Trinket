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
    /// Consumes only the matching prepared key. Returns false when a battle is
    /// already active or the party/enemy IDs do not match; sibling prepares stay.
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
