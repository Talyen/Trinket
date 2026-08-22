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
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    Text(balanced: "Defeat")
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(AccessibilityID.Battle.defeat)

                    Text(balanced: "\(enemyName) has defeated your party.")
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
                .padding(.top, TrinketDesign.Metrics.smallSpacing)
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
        .frame(maxWidth: .infinity)
    }
}
