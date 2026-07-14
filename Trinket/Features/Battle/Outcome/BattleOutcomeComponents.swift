import SwiftUI
import TrinketDesignSystem

struct BattleOutcomeShell<Content: View>: View {
    let symbolName: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String
    @ViewBuilder let content: () -> Content
    let primaryButtonTitle: String
    let primaryButtonAccessibilityIdentifier: String
    let primaryButtonTint: Color?
    let onPrimaryAction: () -> Void

    @State private var symbolAnimationCount = 0
    @State private var isCompleting = false
    @ScaledMetric(relativeTo: .largeTitle) private var outcomeSymbolSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: outcomeSymbolSize, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .symbolEffect(.bounce, value: symbolAnimationCount)
                    .onAppear {
                        symbolAnimationCount += 1
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
                    isCompleting = true
                    onPrimaryAction()
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

struct BattleOutcomeInfoSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(title)
                .trinketTypography(.cardTitle)

            Text(message)
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .trinketCardSurface()
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
