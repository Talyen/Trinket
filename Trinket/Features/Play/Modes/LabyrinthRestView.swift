import SwiftUI
import TrinketDesignSystem

struct LabyrinthRestView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthRestSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("A quiet shrine waits in the stone.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Gold crumb", value: "\(session.goldCrumb)")

                Text("Rest here to claim a small stipend and continue the path.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    appState.finishActiveLabyrinthRest()
                    dismiss()
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
                        appState.dismissActiveLabyrinthRestWithoutCompleting()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthRestLeave)
                }
            }
        }
        .trinketScreenBackground(.playJourney)
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthRest)
        .interactiveDismissDisabled()
    }
}
