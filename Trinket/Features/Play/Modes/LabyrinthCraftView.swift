import SwiftUI
import TrinketDesignSystem

struct LabyrinthCraftView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthCraftSession

    var body: some View {
        LabyrinthNodeEncounterSheet(
            title: "Crafting Altar",
            intro: "Offer gold to the altar. The stone answers with a forged find.",
            screenAccessibilityIdentifier: AccessibilityID.Play.labyrinthCraft,
            leaveButtonTitle: "Close",
            leaveAccessibilityIdentifier: AccessibilityID.Play.labyrinthCraftLeave,
            failureMessage: session.failureMessage,
            failureAccessibilityIdentifier: AccessibilityID.Play.labyrinthCraftFailure,
            onLeave: {
                appState.dismissActiveLabyrinthCraftWithoutCompleting()
                dismiss()
            },
            facts: {
                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Forge cost", value: "\(session.goldCost) Gold")
                LabeledContent("Your gold", value: "\(appState.roster.gold)")
            },
            actions: {
                Button {
                    if appState.forgeActiveLabyrinthCraft() {
                        dismiss()
                    }
                } label: {
                    Text("Forge")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .disabled(appState.roster.gold < session.goldCost)
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftForge)

                Button {
                    if appState.leaveActiveLabyrinthCraftWithoutForging() {
                        dismiss()
                    }
                } label: {
                    Text("Leave without forging")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .trinketQuietTapButtonStyle()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftSkip)
            }
        )
    }
}
