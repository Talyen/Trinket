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
            Text(L10n.ui_coveragediagnosticsview_coverage_diagnostics_292cd)
                .trinketTypography(.footnote)
                .accessibilityIdentifier(AccessibilityID.Debug.coverageDiagnostics)
                .accessibilityValue(report)
                .allowsHitTesting(false)
                .frame(width: 1, height: 1)
                .clipped()
        }
    }

    private var report: String {
        var values: [String: Any] = AudioCoverageDiagnostics.snapshot()
        values["largeText"] = textSize.isAccessibilitySize
        values["largestText"] = textSize == .accessibility5
        values["reduceMotion"] = reduceMotion
        values["fullGameAccess"] = playerSave.contentAccess.allowsChapter(4)
        values["gold"] = playerSave.roster.gold
        values["completedStages"] = playerSave.journey.completedStageIDs.sorted()
        do {
            values["contracts"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(playerSave.contracts))
            return try String(data: JSONSerialization.data(withJSONObject: values), encoding: .utf8) ??
                String(localized: L10n.ui_coveragediagnosticsview_diagnostics_serialization_failed_3dbb1)
        } catch {
            return String(localized: L10n.ui_coveragediagnosticsview_diagnostics_serialization_failed_3dbb1)
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
        .debugFPSOverlay()
    }
}
#endif
