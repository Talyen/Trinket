import Foundation

public enum BattleLifecyclePhase: Equatable, Sendable {
    case idle
    case prepared
    case active
}

@MainActor
public protocol BattleRuntime: AnyObject {
    var activeBattle: BattleRunConfiguration? { get }
    var lifecyclePhase: BattleLifecyclePhase { get }
    var isSuspendedForScenePhase: Bool { get }
    var finalPartyHealthByCombatantID: [String: Int]? { get }

    @discardableResult
    func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool
    func keepPreparedRuns(_ keys: Set<BattleRunKey>)
    func hasPreparedRun(_ runKey: BattleRunKey) -> Bool
    func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?,
    ) -> Bool
    @discardableResult
    func activate(_ configuration: BattleRunConfiguration) -> Bool
    @discardableResult
    func restart(_ configuration: BattleRunConfiguration) -> Bool

    func endBattle()
    func setSuspendedForScenePhase(_ suspended: Bool)
    func trimMemoryFootprint(releaseBattleLog: Bool)
}
