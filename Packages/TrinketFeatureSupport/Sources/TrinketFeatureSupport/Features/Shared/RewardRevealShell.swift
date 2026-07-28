import SwiftUI
import TrinketDesignSystem

public struct RewardRevealShell<Content: View>: View {
    let eyebrow: String?
    let eyebrowAccessibilityIdentifier: String?
    let title: String?
    let subtitle: String?
    var subtitleAccessibilityIdentifier: String?
    let titleAccessibilityIdentifier: String
    var titleColor: Color = .primary
    var eyebrowOpacity: Double = 1
    var titleOpacity: Double = 1
    var subtitleOpacity: Double = 1
    @ViewBuilder let content: () -> Content
    let primaryActionTitle: String?
    let primaryActionAccessibilityIdentifier: String
    let isPrimaryActionDisabled: Bool
    let onPrimaryAction: () -> Void
    var contentTopPadding = TrinketDesign.Metrics.contentTopPadding
    var contentStackSpacing = TrinketDesign.Metrics.sectionSpacing
    var pinsPrimaryActionToBottom = true
    var primaryActionWidthFraction = 1.0

    public init(
        eyebrow: String?,
        eyebrowAccessibilityIdentifier: String?,
        title: String?,
        subtitle: String?,
        subtitleAccessibilityIdentifier: String? = nil,
        titleAccessibilityIdentifier: String,
        titleColor: Color = .primary,
        eyebrowOpacity: Double = 1,
        titleOpacity: Double = 1,
        subtitleOpacity: Double = 1,
        @ViewBuilder content: @escaping () -> Content,
        primaryActionTitle: String?,
        primaryActionAccessibilityIdentifier: String,
        isPrimaryActionDisabled: Bool,
        onPrimaryAction: @escaping () -> Void,
        contentTopPadding: CGFloat = TrinketDesign.Metrics.contentTopPadding,
        contentStackSpacing: CGFloat = TrinketDesign.Metrics.sectionSpacing,
        pinsPrimaryActionToBottom: Bool = true,
        primaryActionWidthFraction: Double = 1
    ) {
        self.eyebrow = eyebrow
        self.eyebrowAccessibilityIdentifier = eyebrowAccessibilityIdentifier
        self.title = title
        self.subtitle = subtitle
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.titleColor = titleColor
        self.eyebrowOpacity = eyebrowOpacity
        self.titleOpacity = titleOpacity
        self.subtitleOpacity = subtitleOpacity
        self.content = content
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityIdentifier = primaryActionAccessibilityIdentifier
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.onPrimaryAction = onPrimaryAction
        self.contentTopPadding = contentTopPadding
        self.contentStackSpacing = contentStackSpacing
        self.pinsPrimaryActionToBottom = pinsPrimaryActionToBottom
        self.primaryActionWidthFraction = primaryActionWidthFraction
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: contentStackSpacing) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    if let eyebrow {
                        Text(eyebrow)
                            .trinketTypography(.eyebrow)
                            .foregroundStyle(TrinketDesign.Colors.accent)
                            .textCase(.uppercase)
                            .opacity(eyebrowOpacity)
                            .accessibilityIdentifier(eyebrowAccessibilityIdentifier ?? eyebrow)
                    }

                    if let title {
                        Text(title)
                            .trinketTypography(.screenDisplay)
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .opacity(titleOpacity)
                            .accessibilityIdentifier(titleAccessibilityIdentifier)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(subtitleOpacity)
                            .accessibilityIdentifier(subtitleAccessibilityIdentifier ?? subtitle)
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
            .padding(.bottom, contentStackSpacing)
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
                                TrinketDesign.Colors.canvas.opacity(0.88),
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
