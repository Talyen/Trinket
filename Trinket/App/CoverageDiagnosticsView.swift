#if DEBUG
import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct CoverageDiagnosticsView: View {
    let playerSave: PlayerSaveStore
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            Text("Coverage diagnostics")
                .trinketTypography(.footnote)
                .accessibilityIdentifier(AccessibilityID.Debug.coverageDiagnostics)
                .accessibilityValue(report)
                .allowsHitTesting(false)
        }
    }

    private var report: String {
        var values: [String: Any] = AudioCoverageDiagnostics.snapshot()
        values["largeText"] = textSize.isAccessibilitySize
        values["largestText"] = textSize == .accessibility5
        values["reduceMotion"] = reduceMotion
        values["gold"] = playerSave.roster.gold
        values["completedStages"] = playerSave.journey.completedStageIDs.sorted()
        do {
            values["contracts"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(playerSave.contracts))
            return try String(data: JSONSerialization.data(withJSONObject: values), encoding: .utf8) ?? "diagnostics serialization failed"
        } catch {
            return "diagnostics serialization failed"
        }
    }
}

extension View {
    func coverageTestEnvironment(playerSave: PlayerSaveStore) -> some View {
        let arguments = ProcessInfo.processInfo.arguments
        let isOwned = arguments.contains("-store-name") && arguments.contains("-disable-cloud-sync")
        return overlay(alignment: .topTrailing) {
            if isOwned, arguments.contains("-coverage-diagnostics") {
                CoverageDiagnosticsView(playerSave: playerSave)
            }
        }
        .transformEnvironment(\.accessibilityReduceMotion) { value in
            if isOwned, arguments.contains("-coverage-reduce-motion") {
                value = true
            }
        }
        .debugFPSOverlay()
    }
}
#endif
