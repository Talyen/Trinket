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
    let isPrimaryActionConfirmed: Bool
    let isPrimaryActionDisabled: Bool
    let onPrimaryAction: () -> Void
    var contentTopPadding = TrinketDesign.Layout.contentTopPadding
    var contentStackSpacing = TrinketDesign.Layout.sectionSpacing
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
        isPrimaryActionConfirmed: Bool = false,
        onPrimaryAction: @escaping () -> Void,
        contentTopPadding: CGFloat = TrinketDesign.Layout.contentTopPadding,
        contentStackSpacing: CGFloat = TrinketDesign.Layout.sectionSpacing,
        pinsPrimaryActionToBottom: Bool = true,
        primaryActionOpacity: Double = 1,
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
        self.isPrimaryActionConfirmed = isPrimaryActionConfirmed
        self.onPrimaryAction = onPrimaryAction
        self.contentTopPadding = contentTopPadding
        self.contentStackSpacing = contentStackSpacing
        self.pinsPrimaryActionToBottom = pinsPrimaryActionToBottom
        self.primaryActionOpacity = primaryActionOpacity
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: contentStackSpacing) {
                VStack(spacing: TrinketDesign.Spacing.small) {
                    VStack(spacing: TrinketDesign.Spacing.extraSmall) {
                        if let eyebrow {
                            Text(balanced: eyebrow)
                                .trinketTypography(.eyebrow)
                                .foregroundStyle(TrinketDesign.Colors.accent)
                                .textCase(.uppercase)
                                .trinketFittedText()
                                .trinketPresentationVisibility(eyebrowOpacity >= 1, opacity: eyebrowOpacity)
                                .offset(y: (1 - eyebrowOpacity) * TrinketDesign.Spacing.small)
                                .accessibilityIdentifier(eyebrowAccessibilityIdentifier ?? eyebrow)
                        }

                        if let title {
                            Text(balanced: title)
                                .trinketTypography(.screenDisplay)
                                .foregroundStyle(titleColor)
                                .multilineTextAlignment(.center)
                                .trinketFittedText()
                                .trinketPresentationVisibility(titleOpacity >= 1, opacity: titleOpacity)
                                .offset(y: (1 - titleOpacity) * TrinketDesign.Spacing.small)
                                .accessibilityIdentifier(titleAccessibilityIdentifier)
                        }
                    }

                    if let subtitle {
                        Text(balanced: subtitle)
                            .trinketTypography(.secondaryBody)
                            .foregroundStyle(subtitleColor)
                            .multilineTextAlignment(.center)
                            .trinketFittedText()
                            .trinketPresentationVisibility(subtitleOpacity >= 1, opacity: subtitleOpacity)
                            .offset(y: (1 - subtitleOpacity) * TrinketDesign.Spacing.small)
                            .accessibilityIdentifier(subtitleAccessibilityIdentifier ?? subtitle)
                    }
                }

                content()

                if !pinsPrimaryActionToBottom {
                    primaryAction
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, contentTopPadding)
            .padding(.bottom, contentStackSpacing)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if pinsPrimaryActionToBottom, primaryActionTitle != nil {
                primaryAction
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                    .padding(.vertical, TrinketDesign.Spacing.medium)
                    .frame(maxWidth: .infinity)
                    .trinketMaterial(.bottomBar, cornerRadius: 0)
                    .background(alignment: .top) {
                        LinearGradient(
                            colors: [
                                TrinketDesign.Colors.canvas.opacity(0),
                                TrinketDesign.Colors.canvas.opacity(0.88),
                            ],
                            startPoint: .top,
                            endPoint: .bottom,
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
                guard !isPrimaryActionDisabled else { return }
                onPrimaryAction()
            } label: {
                ZStack {
                    Text(primaryActionTitle)
                        .opacity(isPrimaryActionConfirmed ? 0 : 1)
                    Label("Collected", systemImage: "checkmark")
                        .opacity(isPrimaryActionConfirmed ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .animation(TrinketMotion.Interaction.stateChange, value: isPrimaryActionConfirmed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isPrimaryActionConfirmed ? "Collected" : primaryActionTitle)
            }
            .trinketPrimaryActionButton()
            .trinketCenteredPrimaryAction()
            .disabled(isPrimaryActionDisabled && !isPrimaryActionConfirmed)
            .allowsHitTesting(!isPrimaryActionDisabled)
            .brightness(isPrimaryActionConfirmed ? 0.06 : 0)
            .animation(TrinketMotion.Reward.collectionLift.repeatCount(2, autoreverses: true), value: isPrimaryActionConfirmed)
            .trinketPresentationVisibility(primaryActionOpacity >= 1, opacity: primaryActionOpacity)
            .offset(y: (1 - primaryActionOpacity) * TrinketDesign.Spacing.small)
            .accessibilityIdentifier(primaryActionAccessibilityIdentifier)
        }
    }
}
