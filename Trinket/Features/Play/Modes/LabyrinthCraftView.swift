import SwiftUI
import TrinketDesignSystem

struct LabyrinthCraftView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: LabyrinthCraftSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Offer gold to the altar. The stone answers with a forged find.")
                    .trinketTypography(.body)
                    .foregroundStyle(.secondary)

                LabeledContent("Depth", value: "\(session.depth)")
                LabeledContent("Forge cost", value: "\(session.goldCost) Gold")
                LabeledContent("Your gold", value: "\(appState.roster.gold)")

                if let failure = session.failureMessage {
                    Text(failure)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(TrinketDesign.Colors.warning)
                        .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftFailure)
                }

                Spacer(minLength: 0)

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
            .padding(TrinketDesign.Metrics.contentMargin)
            .navigationTitle("Crafting Altar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        appState.dismissActiveLabyrinthCraftWithoutCompleting()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraftLeave)
                }
            }
        }
        .trinketScreenBackground()
        .accessibilityIdentifier(AccessibilityID.Play.labyrinthCraft)
        .interactiveDismissDisabled()
    }
}
