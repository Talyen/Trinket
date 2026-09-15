import BattleEngine
import TrinketFeatureSupport
#if DEBUG
import SwiftUI

struct BattlePerformanceScenarioHarness: View {
    let scenario: BattlePerformanceScenario
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState

    @State private var status = "ready"
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: start) {
                Image(systemName: "play.fill")
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Start battle performance scenario")
            }
            .buttonStyle(.plain)
            .disabled(status != "ready")
            .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStart)

            Text(status)
                // UIStyleCheck: allow - Hidden status probe exists only for performance automation.
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStatus)
                .accessibilityValue(status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.performanceScenario,
            isActive: status.hasPrefix("measuring:"),
        )
        .onReceive(NotificationCenter.default.publisher(for: FramePacingMeasurementControl.finished)) { _ in
            markComplete()
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func start() {
        status = "preparing:\(scenario.rawValue)"
        castPresentation.reset()
        battleSession.feedback.clear()
        battleSession.clearSpectacle()
        CombatFeedbackRasterPool.shared.resetDiagnostics()

        let driver = BattlePerformanceScenarioDriver(
            scenario: scenario,
            battleSession: battleSession,
            battleSize: battleSize,
            castPresentation: castPresentation,
        )
        task = Task { @MainActor in
            NotificationCenter.default.post(name: FramePacingMeasurementControl.reset, object: nil)
            try? await Task.sleep(for: .seconds(FramePacingMeasurementTiming.monitorWarmupSeconds + 0.15))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: FramePacingMeasurementControl.begin, object: nil)

            status = "measuring:\(scenario.rawValue)"
            if let failure = driver.perform() {
                status = "failed:\(scenario.rawValue):\(failure)"
            }
        }
    }

    private func markComplete() {
        guard status.hasPrefix("measuring:") else { return }
        let raster = CombatFeedbackRasterPool.shared.snapshot()
        status = "complete:\(scenario.rawValue)"
            + ":scenarioSeed=\(battleSession.activeBattle?.rngSeed ?? 0)"
            + ":rasterHits=\(raster.hitCount)"
            + ":rasterMisses=\(raster.missCount)"
            + ":rasterBuilds=\(raster.buildCount)"
            + ":numericRasterMisses=\(raster.numericMissCount)"
            + ":unexpectedClosedVocabularyBuilds=\(raster.unexpectedClosedVocabularyBuildCount)"
    }
}
#endif
