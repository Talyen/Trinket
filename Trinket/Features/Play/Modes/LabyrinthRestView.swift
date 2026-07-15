import SwiftUI
import TrinketDesignSystem

struct LabyrinthRestView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthNodeSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("A quiet shrine waits in the stone.")
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)

                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Gold crumb", value: "\(session.goldAmount)")

                Text("Rest here to claim a small stipend and continue the path.")
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(.secondary)

                if let failure = session.failureMessage {
                    Text(failure)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(TrinketDesign.Colors.warning)
                        .accessibilityIdentifier(AccessibilityID.Play.labyrinthRestFailure)
                }

                Spacer(minLength: 0)

                Button {
                    if appState.finishActiveLabyrinthRest() {
                        dismiss()
                    }
                } label: {
                    Text("Rest")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthRestConfirm)
            }
            .padding(TrinketDesign.Metrics.contentMargin)
            .navigationTitle("Shrine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Leave") {
                        appState.dismissActiveLabyrinthNodeSessionWithoutCompleting()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthRestLeave)
                }
            }
        }
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthRest)
        .interactiveDismissDisabled()
    }
}
