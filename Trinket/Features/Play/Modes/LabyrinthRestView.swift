import SwiftUI
import TrinketAppState
import TrinketDesignSystem
import TrinketFeatureSupport

struct LabyrinthRestView: View {
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthNodeSession

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
                labyrinth.activeNodeSession = nil
                dismiss()
            },
            facts: {
                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Gold crumb", value: "\(session.goldAmount)")
            },
            actions: {
                Button {
                    if labyrinth.finishActiveRest() {
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
