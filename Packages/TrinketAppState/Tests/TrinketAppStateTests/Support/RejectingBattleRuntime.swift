import BattleEngine
import Foundation
import TrinketFeatureContracts

@MainActor
class RejectingBattleRuntime: BattleRuntime {
    var resolvedDefeatProgress: BattleDefeatProgress? {
        nil
    }

    var activeBattle: BattleRunConfiguration?
    var lifecyclePhase: BattleLifecyclePhase = .idle
    var isSuspendedForScenePhase = false
    var finalPartyHealthByCombatantID: [String: Int]?
    weak var progression: (any BattleProgressionDelegate)?

    func connectProgression(to delegate: any BattleProgressionDelegate) {
        progression = delegate
    }

    func createPreparedRun(_: BattleRunConfiguration) -> (any PreparedBattleRunHandle)? {
        nil
    }

    func publishPreparedPreview(_ preview: BattlePreparedPreview) {
        if activeBattle == nil {
            lifecyclePhase = preview.configurations.isEmpty ? .idle : .prepared
        }
    }

    func activatePreparedBattle(_: any PreparedBattleRunHandle, presentation _: BattlePresentationContext) -> Bool {
        false
    }

    func activate(_: BattleRunConfiguration, presentation _: BattlePresentationContext) -> Bool {
        false
    }

    func restart(_: BattleRunConfiguration, presentation _: BattlePresentationContext) -> Bool {
        false
    }

    func endBattle() {
        activeBattle = nil; lifecyclePhase = .idle
    }

    func setSuspendedForScenePhase(_ suspended: Bool) {
        isSuspendedForScenePhase = suspended
    }

    func trimMemoryFootprint(releaseBattleLog _: Bool) {}
}

@MainActor
final class FixturePreparedRun: PreparedBattleRunHandle {
    let configuration: BattleRunConfiguration
    var isValid = true
    init(_ configuration: BattleRunConfiguration) {
        self.configuration = configuration
    }

    func invalidate() {
        isValid = false
    }
}

@MainActor
final class PreparedThenRejectingBattleRuntime: RejectingBattleRuntime {
    private(set) var prepareCount = 0
    var shouldRejectActivation = true
    var shouldRejectPreparation = false
    var onRestart: ((BattleRunConfiguration, BattlePresentationContext) -> Void)?

    override func createPreparedRun(_ configuration: BattleRunConfiguration) -> (any PreparedBattleRunHandle)? {
        prepareCount += 1
        return shouldRejectPreparation ? nil : FixturePreparedRun(configuration)
    }

    override func activatePreparedBattle(_ handle: any PreparedBattleRunHandle, presentation _: BattlePresentationContext) -> Bool {
        guard !shouldRejectActivation, let run = handle as? FixturePreparedRun, run.isValid else { return false }
        run.invalidate()
        activeBattle = run.configuration
        lifecyclePhase = .active
        return true
    }

    override func restart(_ configuration: BattleRunConfiguration, presentation: BattlePresentationContext) -> Bool {
        onRestart?(configuration, presentation)
        return false
    }

    override func activate(_ configuration: BattleRunConfiguration, presentation _: BattlePresentationContext) -> Bool {
        guard !shouldRejectActivation else { return false }
        activeBattle = configuration
        lifecyclePhase = .active
        return true
    }
}
