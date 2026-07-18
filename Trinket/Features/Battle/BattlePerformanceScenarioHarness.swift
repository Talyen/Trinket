#if DEBUG
import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Explicit, test-only workload driver. It invokes production Battle presentation paths
/// and never swaps effects for cheaper test implementations.
struct BattlePerformanceScenarioHarness: View {
    let scenario: BattlePerformanceScenario
    let appState: AppState
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState
    let forcedDrag: BattleForcedDragState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    @State private var status = "ready"
    @State private var generation = 0
    @State private var task: Task<Void, Never>?

    private static var measurementDuration: Duration {
        BattlePerformanceTiming.harnessMeasure
    }

    private static var measurementWarmup: Duration {
        BattlePerformanceTiming.harnessWarmup
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button {
                start()
            } label: {
                Image(systemName: "play.fill")
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(status == "running")
            .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStart)

            Text(status)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                // UIStyleCheck: allow - Hidden status probe exists only for performance UI-test automation.
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(AccessibilityID.Debug.battlePerformanceStatus)
                .accessibilityValue(status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.performanceScenario,
            isActive: status == "running"
        )
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func start() {
        task?.cancel()
        generation &+= 1
        let runGeneration = generation
        status = "running"
        forcedDrag.clear()
        castPresentation.reset()
        battleSession.clearFeedback()
        battleSession.clearSpectacle()
        CombatFeedbackRasterPool.shared.removeAll()
        CombatFeedbackRasterPool.shared.resetDiagnostics()
        let scenarioDriver = driver
        if scenario != .feedbackRasterCold {
            scenarioDriver.prepareFeedbackRasters(runGeneration: runGeneration)
            CombatFeedbackRasterPool.shared.resetDiagnostics()
        }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.performanceScenario,
            detail: "phase=start scenario=\(scenario.rawValue) run=\(runGeneration)"
        )

        task = Task { @MainActor in
            await battlePerformancePrimeChipHostPipeline(
                scenario: scenario,
                battleSession: battleSession,
                runGeneration: runGeneration
            )
            battleSession.clearFeedback()
            CombatFeedbackChipBridge.publish(.reset)
            reseedFeedbackRastersAfterPrime(runGeneration: runGeneration)
            NotificationCenter.default.post(name: FramePacingMeasurementControl.reset, object: nil)
            try? await Task.sleep(for: Self.measurementWarmup)
            guard !Task.isCancelled, runGeneration == generation else { return }
            let clock = ContinuousClock()
            let startedAt = clock.now
            await scenarioDriver.perform(runGeneration: runGeneration)
            let elapsed = startedAt.duration(to: clock.now)
            if elapsed < Self.measurementDuration {
                try? await Task.sleep(for: Self.measurementDuration - elapsed)
            }
            guard !Task.isCancelled, runGeneration == generation else { return }
            forcedDrag.clear()
            markScenarioComplete(runGeneration: runGeneration)
        }
    }

    private func reseedFeedbackRastersAfterPrime(runGeneration: Int) {
        if scenario == .feedbackRasterCold {
            CombatFeedbackRasterPool.shared.removeAll()
            CombatFeedbackRasterPool.shared.resetDiagnostics()
        } else if scenario == .feedbackRasterWarm
            || scenario == .feedbackChipsOnly
            || scenario == .denseFeedback {
            driver.prepareFeedbackRasters(runGeneration: runGeneration)
            CombatFeedbackRasterPool.shared.resetDiagnostics()
        }
    }

    private func markScenarioComplete(runGeneration: Int) {
        let rasterSnapshot = CombatFeedbackRasterPool.shared.snapshot()
        status = "complete:\(scenario.rawValue):\(runGeneration)"
            + ":rasterEntries=\(rasterSnapshot.entryCount)"
            + ":rasterBytes=\(rasterSnapshot.estimatedByteCount)"
            + ":rasterHits=\(rasterSnapshot.hitCount)"
            + ":rasterBuilds=\(rasterSnapshot.buildCount)"
            + ":rasterEvictions=\(rasterSnapshot.evictionCount)"
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.performanceScenario,
            detail: "phase=complete scenario=\(scenario.rawValue) run=\(runGeneration) "
                + "rasterEntries=\(rasterSnapshot.entryCount) rasterHits=\(rasterSnapshot.hitCount) "
                + "rasterBytes=\(rasterSnapshot.estimatedByteCount) "
                + "rasterBuilds=\(rasterSnapshot.buildCount) rasterEvictions=\(rasterSnapshot.evictionCount)"
        )
    }

    private var driver: BattlePerformanceScenarioDriver {
        BattlePerformanceScenarioDriver(
            scenario: scenario,
            appState: appState,
            battleSession: battleSession,
            battleSize: battleSize,
            castPresentation: castPresentation,
            forcedDrag: forcedDrag,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }
}
#endif
