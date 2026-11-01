import BattleEngine
import Foundation
import TrinketContent
import TrinketFeatureContracts

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
final class RejectingBattleRuntime: BattleRuntime {
    var activeBattle: BattleRunConfiguration?
    var resolvedDefeatProgress: BattleDefeatProgress?
    var isSuspendedForScenePhase = false
    var finalPartyHealthByCombatantID: [String: Int]?
    weak var progression: (any BattleProgressionDelegate)?

    private(set) var prepareCount = 0
    var shouldRejectPreparation: Bool
    var shouldRejectActivation: Bool
    var onRestart: ((BattleRunConfiguration, BattlePresentationContext) -> Void)?
    private var hasPreparedPreview = false

    init(
        shouldRejectPreparation: Bool = false,
        shouldRejectActivation: Bool = true,
    ) {
        self.shouldRejectPreparation = shouldRejectPreparation
        self.shouldRejectActivation = shouldRejectActivation
    }

    var lifecyclePhase: BattleLifecyclePhase {
        if activeBattle != nil {
            return .active
        }
        return hasPreparedPreview ? .prepared : .idle
    }

    func connectProgression(to delegate: any BattleProgressionDelegate) {
        progression = delegate
    }

    func createPreparedRun(_ configuration: BattleRunConfiguration) -> (any PreparedBattleRunHandle)? {
        prepareCount += 1
        return shouldRejectPreparation ? nil : FixturePreparedRun(configuration)
    }

    func publishPreparedPreview(_ preview: BattlePreparedPreview) {
        hasPreparedPreview = !preview.configurations.isEmpty
    }

    func activatePreparedBattle(_ handle: any PreparedBattleRunHandle, presentation _: BattlePresentationContext) -> Bool {
        guard !shouldRejectActivation, let run = handle as? FixturePreparedRun, run.isValid else { return false }
        run.invalidate()
        activeBattle = run.configuration
        return true
    }

    func activate(_ configuration: BattleRunConfiguration, presentation _: BattlePresentationContext) -> Bool {
        guard !shouldRejectActivation else { return false }
        activeBattle = configuration
        return true
    }

    func restart(_ configuration: BattleRunConfiguration, presentation: BattlePresentationContext) -> Bool {
        onRestart?(configuration, presentation)
        return false
    }

    func endBattle() {
        activeBattle = nil
        hasPreparedPreview = false
    }

    func setSuspendedForScenePhase(_ suspended: Bool) {
        isSuspendedForScenePhase = suspended
    }

    func trimMemoryFootprint(releaseBattleLog _: Bool) {}
}
