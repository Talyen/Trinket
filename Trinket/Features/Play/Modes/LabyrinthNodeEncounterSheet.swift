import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

/// Shared NavigationStack chrome for Labyrinth rest / craft node sheets.
/// Mode-specific facts and actions stay at the call site.
struct LabyrinthNodeEncounterSheet<Facts: View, Actions: View>: View {
    let title: String
    let intro: String
    var detail: String?
    let screenAccessibilityIdentifier: String
    let leaveButtonTitle: String
    let leaveAccessibilityIdentifier: String
    let failureMessage: String?
    let failureAccessibilityIdentifier: String
    let onLeave: () -> Void
    @ViewBuilder let facts: () -> Facts
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.contentMargin) {
                Text(intro)
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)

                facts()

                if let detail {
                    Text(detail)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                }

                if let failureMessage {
                    Text(failureMessage)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(TrinketDesign.Colors.warning)
                        .accessibilityIdentifier(failureAccessibilityIdentifier)
                }

                Spacer(minLength: 0)

                actions()
            }
            .padding(TrinketDesign.Metrics.contentMargin)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(leaveButtonTitle, action: onLeave)
                        .accessibilityIdentifier(leaveAccessibilityIdentifier)
                }
            }
        }
        .trinketScreenBackground()
        .accessibilityIdentifier(screenAccessibilityIdentifier)
        .interactiveDismissDisabled()
    }
}
