import TrinketFeatureSupport
#if DEBUG
import SwiftUI
import TrinketPersistence

/// A small measurement shell around production battle UI. Finger-driven scenarios
/// are stimulated by XCUI; component gates use the same session mutation methods.
struct BattlePerformanceScenarioHarness: View {
    let scenario: BattlePerformanceScenario
    let journey: JourneyProgressState
    let homestead: PlayerHomesteadState
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
            }
            .buttonStyle(.plain)
            .disabled(status != "ready")
            .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStart)

            Text(status)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                // UIStyleCheck: allow - Hidden status probe exists only for performance automation.
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStatus)
                .accessibilityValue(status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.performanceScenario,
            isActive: status.hasPrefix("measuring:")
        )
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func start() {
        status = "priming:\(scenario.rawValue)"
        castPresentation.reset()
        battleSession.feedback.clear()
        battleSession.clearSpectacle()
        CombatFeedbackRasterPool.shared.resetDiagnostics()

        let driver = BattlePerformanceScenarioDriver(
            scenario: scenario,
            journey: journey,
            homestead: homestead,
            battleSession: battleSession,
            battleSize: battleSize,
            castPresentation: castPresentation
        )
        task = Task { @MainActor in
            await battlePerformancePrimeChipHostPipeline(
                scenario: scenario,
                battleSession: battleSession
            )
            NotificationCenter.default.post(name: FramePacingMeasurementControl.reset, object: nil)
            try? await Task.sleep(for: BattlePerformanceTiming.harnessWarmup)
            guard !Task.isCancelled else { return }

            status = "measuring:\(scenario.rawValue)"
            let clock = ContinuousClock()
            let startedAt = clock.now
            let failure = driver.perform()
            let elapsed = startedAt.duration(to: clock.now)
            if elapsed < BattlePerformanceTiming.harnessMeasure {
                try? await Task.sleep(for: BattlePerformanceTiming.harnessMeasure - elapsed)
            }
            guard !Task.isCancelled else { return }
            if let failure {
                status = "failed:\(scenario.rawValue):\(failure)"
            } else {
                markComplete()
            }
        }
    }

    private func markComplete() {
        let raster = CombatFeedbackRasterPool.shared.snapshot()
        status = "complete:\(scenario.rawValue)"
            + ":scenarioSeed=\(battleSession.activeBattle?.rngSeed ?? 0)"
            + ":rasterHits=\(raster.hitCount)"
            + ":rasterMisses=\(raster.missCount)"
            + ":rasterBuilds=\(raster.buildCount)"
    }
}
#endif
