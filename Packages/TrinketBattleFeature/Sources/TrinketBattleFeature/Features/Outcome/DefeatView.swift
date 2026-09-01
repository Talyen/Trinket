import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct DefeatView: View {
    let enemyName: String
    var primaryButtonTitle: String = "Retry"
    let onPrimaryAction: () -> Bool

    @State private var isCompleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: TrinketDesign.Layout.sectionSpacing) {
                VStack(spacing: TrinketDesign.Spacing.small) {
                    Text(balanced: "Defeat")
                        .trinketTypography(.screenTitle)
                        .trinketFittedText()
                        .accessibilityIdentifier(AccessibilityID.Battle.defeat)

                    Text(balanced: "\(enemyName) has defeated your party.")
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                }

                Button {
                    guard !isCompleting else { return }
                    isCompleting = onPrimaryAction()
                } label: {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .trinketCenteredPrimaryAction()
                .tint(TrinketDesign.Colors.destructive)
                .disabled(isCompleting)
                .accessibilityIdentifier(AccessibilityID.Battle.defeatPrimaryButton)
                .padding(.top, TrinketDesign.Spacing.small)
            }
            .padding(TrinketDesign.Spacing.extraLarge)
        }
        .frame(maxWidth: .infinity)
    }
}
