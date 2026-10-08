import BattleEngine
import TrinketContent

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
    var resolvedDefeatProgress: BattleDefeatProgress? { get }
    var finalPartyHealthByCombatantID: [String: Int]? { get }

    func connectProgression(to delegate: any BattleProgressionDelegate)
    func createPreparedRun(_ configuration: BattleRunConfiguration) -> (any PreparedBattleRunHandle)?
    func publishPreparedPreview(_ preview: BattlePreparedPreview)
    @discardableResult
    func activatePreparedBattle(_ handle: any PreparedBattleRunHandle, presentation: BattlePresentationContext) -> Bool
    @discardableResult
    func activate(_ configuration: BattleRunConfiguration, presentation: BattlePresentationContext) -> Bool
    @discardableResult
    func restart(_ configuration: BattleRunConfiguration, presentation: BattlePresentationContext) -> Bool

    func endBattle()
    func setSuspendedForScenePhase(_ suspended: Bool)
    func trimMemoryFootprint(releaseBattleLog: Bool)
}
