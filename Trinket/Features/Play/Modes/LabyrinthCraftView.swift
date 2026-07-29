import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct LabyrinthCraftView: View {
    @Environment(LabyrinthPlayMode.self) private var labyrinth
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthNodeSession

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
                labyrinth.dismissActiveNodeSessionWithoutCompleting()
                dismiss()
            },
            facts: {
                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Forge cost", value: "\(session.goldAmount) Gold")
                LabeledContent("Your gold", value: "\(playerSave.roster.gold)")
            },
            actions: {
                Button {
                    if labyrinth.forgeActiveCraft() {
                        dismiss()
                    }
                } label: {
                    Text("Forge")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .disabled(playerSave.roster.gold < session.goldAmount)
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftForge)

                Button {
                    if labyrinth.leaveActiveCraftWithoutForging() {
                        dismiss()
                    }
                } label: {
                    Text("Leave without forging")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TrinketDesign.Metrics.sectionHeaderSpacing)
                }
                .trinketQuietTapButtonStyle()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftSkip)
            }
        )
    }
}
