import SwiftUI
import TrinketDesignSystem

struct LabyrinthRestView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthRestSession

    var body: some View {
        LabyrinthNodeEncounterSheet(
            title: "Shrine",
            intro: "A quiet shrine waits in the stone.",
            detail: "Rest here to claim a small stipend and continue the path.",
            screenAccessibilityIdentifier: AccessibilityID.Play.labyrinthRest,
            leaveButtonTitle: "Leave",
            leaveAccessibilityIdentifier: AccessibilityID.Play.labyrinthRestLeave,
            failureMessage: session.failureMessage,
            failureAccessibilityIdentifier: AccessibilityID.Play.labyrinthRestFailure,
            onLeave: {
                appState.dismissActiveLabyrinthRestWithoutCompleting()
                dismiss()
            },
            facts: {
                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Gold crumb", value: "\(session.goldCrumb)")
            },
            actions: {
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
        )
    }
}
