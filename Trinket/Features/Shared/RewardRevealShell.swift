import SwiftUI
import TrinketDesignSystem

struct RewardRevealShell<Content: View>: View {
    let eyebrow: String?
    let eyebrowAccessibilityIdentifier: String?
    let title: String
    let subtitle: String?
    let titleAccessibilityIdentifier: String
    var titleColor: Color = .primary
    @ViewBuilder let content: () -> Content
    let primaryActionTitle: String?
    let primaryActionAccessibilityIdentifier: String
    let isPrimaryActionDisabled: Bool
    let onPrimaryAction: () -> Void
    var contentTopPadding = TrinketDesign.Metrics.contentTopPadding
    var pinsPrimaryActionToBottom = true
    var primaryActionWidthFraction = 1.0

    var body: some View {
        ScrollView {
            VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    if let eyebrow {
                        Text(eyebrow)
                            .trinketTypography(.eyebrow)
                            .foregroundStyle(TrinketDesign.Colors.accent)
                            .textCase(.uppercase)
                            .accessibilityIdentifier(eyebrowAccessibilityIdentifier ?? eyebrow)
                    }

                    Text(title)
                        .trinketTypography(.screenDisplay)
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(titleAccessibilityIdentifier)

                    if let subtitle {
                        Text(subtitle)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                content()

                if !pinsPrimaryActionToBottom {
                    primaryAction
                        .containerRelativeFrame(.horizontal) { width, _ in
                            width * primaryActionWidthFraction
                        }
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.top, contentTopPadding)
            .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if pinsPrimaryActionToBottom, primaryActionTitle != nil {
                primaryAction
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
                    .frame(maxWidth: .infinity)
                    .trinketMaterial(.bottomBar, cornerRadius: 0)
                    .background(alignment: .top) {
                        LinearGradient(
                            colors: [
                                TrinketDesign.Colors.canvas.opacity(0),
                                TrinketDesign.Colors.canvas.opacity(0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 28)
                        .offset(y: -28)
                        .allowsHitTesting(false)
                    }
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let primaryActionTitle {
            Button {
                onPrimaryAction()
            } label: {
                Text(primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .disabled(isPrimaryActionDisabled)
            .accessibilityIdentifier(primaryActionAccessibilityIdentifier)
        }
    }
}
