import TrinketContent
import TrinketFeatureSupport
import XCTest

final class ShellPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testSamplerDetectsStall() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-frame-metrics-validation-stall"])
            measured("diagnostic-stall", iteration: iteration) { play.assertLoaded() }
            let value = any(AccessibilityID.Debug.frameMetrics).value as? String ?? ""
            let report = FramePacingReport.parseAccessibilityValue(value)
            XCTAssertGreaterThan(report?.maxFrameMs ?? 0, 80)
            XCTAssertGreaterThan(report?.severeStallCount ?? 0, 0)
        }
    }
}
