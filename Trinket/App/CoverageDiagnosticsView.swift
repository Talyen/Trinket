#if DEBUG
import StoreKit
import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct CoverageDiagnosticsView: View {
    let appState: AppState
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var storeKitEntitlements = [String]()

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
        .task {
            while !Task.isCancelled {
                var entitlements = [String]()
                for await result in Transaction.currentEntitlements {
                    switch result {
                    case let .verified(transaction):
                        entitlements
                            .append(
                                "verified id=\(transaction.id) product=\(transaction.productID) revoked=\(transaction.revocationDate != nil)",
                            )
                    case let .unverified(transaction, _):
                        entitlements.append("unverified id=\(transaction.id) product=\(transaction.productID)")
                    }
                }
                storeKitEntitlements = entitlements
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var report: String {
        let playerSave = appState.playerSave
        var values: [String: Any] = AudioCoverageDiagnostics.snapshot()
        values["largeText"] = textSize.isAccessibilitySize
        values["largestText"] = textSize == .accessibility5
        values["reduceMotion"] = reduceMotion
        values["fullGameAccess"] = playerSave.contentAccess.allowsChapter(4)
        values["fullGameOwnership"] = String(describing: appState.fullGame.ownership)
        values["storeKitEntitlements"] = storeKitEntitlements
        values["fullGameOutcome"] = appState.fullGame.outcome.map { String(describing: $0) } ?? "none"
        values["gameplayActive"] = appState.play.isGameplayActive
        values["selectedTab"] = appState.shellSession.selectedTab.rawValue
        values["playPath"] = appState.shellSession.playPath.map(\.id)
        values["pendingPlayDestination"] = appState.play.pendingDestination?.id ?? "none"
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
    func coverageTestEnvironment(appState: AppState) -> some View {
        let arguments = ProcessInfo.processInfo.arguments
        let isOwned = arguments.contains("-store-name") && arguments.contains("-disable-cloud-sync")
        return overlay(alignment: .topTrailing) {
            if isOwned, arguments.contains("-coverage-diagnostics") {
                CoverageDiagnosticsView(appState: appState)
            }
        }
        .debugFPSOverlay()
    }
}
#endif
