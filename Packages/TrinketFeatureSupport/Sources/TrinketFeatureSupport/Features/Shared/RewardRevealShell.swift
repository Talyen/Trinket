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
    var subtitleColor: Color = .secondary
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
    var primaryActionOpacity: Double = 1

    public init(
        eyebrow: String?,
        eyebrowAccessibilityIdentifier: String?,
        title: String?,
        subtitle: String?,
        subtitleAccessibilityIdentifier: String? = nil,
        titleAccessibilityIdentifier: String,
        titleColor: Color = .primary,
        subtitleColor: Color = .secondary,
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
        primaryActionOpacity: Double = 1
    ) {
        self.eyebrow = eyebrow
        self.eyebrowAccessibilityIdentifier = eyebrowAccessibilityIdentifier
        self.title = title
        self.subtitle = subtitle
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
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
        self.primaryActionOpacity = primaryActionOpacity
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: contentStackSpacing) {
                VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                    if let eyebrow {
                        Text(balanced: eyebrow)
                            .trinketTypography(.eyebrow)
                            .foregroundStyle(TrinketDesign.Colors.accent)
                            .textCase(.uppercase)
                            .opacity(eyebrowOpacity)
                            .offset(y: (1 - eyebrowOpacity) * TrinketDesign.Metrics.smallSpacing)
                            .accessibilityHidden(eyebrowOpacity < 1)
                            .accessibilityIdentifier(eyebrowAccessibilityIdentifier ?? eyebrow)
                    }

                    if let title {
                        Text(balanced: title)
                            .trinketTypography(.screenDisplay)
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .opacity(titleOpacity)
                            .offset(y: (1 - titleOpacity) * TrinketDesign.Metrics.smallSpacing)
                            .accessibilityHidden(titleOpacity < 1)
                            .accessibilityIdentifier(titleAccessibilityIdentifier)
                    }

                    if let subtitle {
                        Text(balanced: subtitle)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(subtitleColor)
                            .multilineTextAlignment(.center)
                            .opacity(subtitleOpacity)
                            .offset(y: (1 - subtitleOpacity) * TrinketDesign.Metrics.smallSpacing)
                            .accessibilityHidden(subtitleOpacity < 1)
                            .accessibilityIdentifier(subtitleAccessibilityIdentifier ?? subtitle)
                    }
                }

                content()

                if !pinsPrimaryActionToBottom {
                    primaryAction
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
            .trinketCenteredPrimaryAction()
            .disabled(isPrimaryActionDisabled)
            .opacity(primaryActionOpacity)
            .offset(y: (1 - primaryActionOpacity) * TrinketDesign.Metrics.smallSpacing)
            .accessibilityHidden(primaryActionOpacity < 1)
            .allowsHitTesting(primaryActionOpacity >= 1 && !isPrimaryActionDisabled)
            .accessibilityIdentifier(primaryActionAccessibilityIdentifier)
        }
    }
}
