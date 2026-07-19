import SwiftUI
import TrinketDesignSystem

struct BattleOutcomeShell<Content: View>: View {
    var symbolName: String?
    var symbolColor: Color?
    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String
    @ViewBuilder let content: () -> Content
    let primaryButtonTitle: String
    let primaryButtonAccessibilityIdentifier: String
    let primaryButtonTint: Color?
    /// Returns `true` when the outcome action succeeded and the button should stay locked.
    let onPrimaryAction: () -> Bool

    @State private var symbolAnimationCount = 0
    @State private var isCompleting = false
    @ScaledMetric(relativeTo: .largeTitle) private var outcomeSymbolSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                if let symbolName, let symbolColor {
                    Image(systemName: symbolName)
                        .font(.system(size: outcomeSymbolSize, weight: .semibold))
                        .foregroundStyle(symbolColor)
                        .symbolEffect(.bounce, value: symbolAnimationCount)
                        .onAppear {
                            symbolAnimationCount += 1
                        }
                }

                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    Text(title)
                        .trinketTypography(.screenTitle)
                        .accessibilityIdentifier(titleAccessibilityIdentifier)

                    Text(subtitle)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                content()

                Button {
                    guard !isCompleting else { return }
                    isCompleting = onPrimaryAction()
                } label: {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(primaryButtonTint)
                .disabled(isCompleting)
                .accessibilityIdentifier(primaryButtonAccessibilityIdentifier)
                .padding(.top, TrinketDesign.Metrics.smallSpacing)
            }
            .padding(TrinketDesign.Metrics.extraLargeSpacing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BattleOutcomeRewardRow: View {
    let symbolName: String
    let tint: Color
    let text: String

    var body: some View {
        Label {
            Text(text)
                .trinketTypography(.secondaryBody)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
        }
    }
}
