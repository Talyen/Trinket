import Foundation
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
    let secondaryActionTitle: String?
    let secondaryActionAccessibilityIdentifier: String?
    let onSecondaryAction: () -> Void
    var contentTopPadding = TrinketDesign.Layout.contentTopPadding
    var contentStackSpacing = TrinketDesign.Layout.sectionSpacing
    var pinsPrimaryActionToBottom: Bool?
    @ScaledMetric(relativeTo: .body) private var minimumInlineHeight: CGFloat = 600
    var primaryActionOpacity: Double = 1
    var primaryActionEntranceOffset: CGFloat = TrinketDesign.Spacing.small

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
        secondaryActionTitle: String? = nil,
        secondaryActionAccessibilityIdentifier: String? = nil,
        onSecondaryAction: @escaping () -> Void = {},
        contentTopPadding: CGFloat = TrinketDesign.Layout.contentTopPadding,
        contentStackSpacing: CGFloat = TrinketDesign.Layout.sectionSpacing,
        pinsPrimaryActionToBottom: Bool? = nil,
        primaryActionOpacity: Double = 1,
        primaryActionEntranceOffset: CGFloat = TrinketDesign.Spacing.small,
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
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryActionAccessibilityIdentifier = secondaryActionAccessibilityIdentifier
        self.onSecondaryAction = onSecondaryAction
        self.contentTopPadding = contentTopPadding
        self.contentStackSpacing = contentStackSpacing
        self.pinsPrimaryActionToBottom = pinsPrimaryActionToBottom
        self.primaryActionOpacity = primaryActionOpacity
        self.primaryActionEntranceOffset = primaryActionEntranceOffset
    }

    public var body: some View {
        GeometryReader { geometry in
            let pinsActions = pinsPrimaryActionToBottom
                ?? (geometry.size.width > geometry.size.height || geometry.size.height < minimumInlineHeight)
            scrollContent(pinsActions: pinsActions)
        }
    }

    private func scrollContent(pinsActions: Bool) -> some View {
        ScrollView {
            VStack(spacing: contentStackSpacing) {
                heading

                content()

                if !pinsActions {
                    actions
                }
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, contentTopPadding)
            .padding(.bottom, contentStackSpacing)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
        .clipped()
        .safeAreaInset(edge: .bottom) {
            if pinsActions, primaryActionTitle != nil {
                actions
                    .padding(.horizontal, TrinketDesign.Layout.contentMargin)
                    .padding(.vertical, TrinketDesign.Spacing.medium)
                    .frame(maxWidth: .infinity)
                    .trinketMaterial(.bottomBar, cornerRadius: 0)
            }
        }
    }

    private var heading: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            VStack(spacing: TrinketDesign.Spacing.extraSmall) {
                if let eyebrow {
                    GameLabel(eyebrow, balanced: true)
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(TrinketDesign.Colors.accent)
                        .textCase(.uppercase)
                        .trinketFittedText()
                        .trinketPresentationVisibility(eyebrowOpacity >= 1, opacity: eyebrowOpacity)
                        .offset(y: (1 - eyebrowOpacity) * TrinketDesign.Spacing.small)
                        .accessibilityIdentifier(eyebrowAccessibilityIdentifier ?? eyebrow)
                }

                if let title {
                    GameLabel(title, balanced: true)
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
                GameLabel(subtitle, balanced: true)
                    .trinketTypography(.secondaryBody)
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
                    .trinketPresentationVisibility(subtitleOpacity >= 1, opacity: subtitleOpacity)
                    .offset(y: (1 - subtitleOpacity) * TrinketDesign.Spacing.small)
                    .accessibilityIdentifier(subtitleAccessibilityIdentifier ?? subtitle)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: TrinketDesign.Spacing.large) {
            primaryAction
            if let secondaryActionTitle {
                Button {
                    guard !isPrimaryActionDisabled else { return }
                    onSecondaryAction()
                } label: {
                    GameLabel(secondaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketSecondaryActionButton(accessibilityIdentifier: secondaryActionAccessibilityIdentifier)
                .trinketCenteredPrimaryAction()
                .disabled(isPrimaryActionDisabled)
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let primaryActionTitle {
            Button {
                #if DEBUG
                NSLog("%@", "VICTORY_DIAG shell disabled=\(isPrimaryActionDisabled) confirmed=\(isPrimaryActionConfirmed)")
                #endif
                guard !isPrimaryActionDisabled else { return }
                onPrimaryAction()
            } label: {
                ZStack {
                    if #available(iOS 26.0, *) {
                        GameLabel(primaryActionTitle)
                            .trinketPresentationVisibility(!isPrimaryActionConfirmed)
                        Label(String(localized: L10n.ui_rewardrevealshell_collected_1533d), systemImage: "checkmark")
                            .trinketPresentationVisibility(isPrimaryActionConfirmed)
                    } else if isPrimaryActionConfirmed {
                        // iOS 18 audits invisible label children despite accessibilityHidden.
                        Label(String(localized: L10n.ui_rewardrevealshell_collected_1533d), systemImage: "checkmark")
                            .transition(.opacity)
                    } else {
                        GameLabel(primaryActionTitle)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(TrinketMotion.Interaction.stateChange, value: isPrimaryActionConfirmed)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isPrimaryActionConfirmed ? String(localized: L10n.ui_rewardrevealshell_collected_1533d) :
                    primaryActionTitle)
            }
            .trinketPrimaryActionButton()
            .trinketCenteredPrimaryAction()
            .disabled(isPrimaryActionDisabled && !isPrimaryActionConfirmed)
            .allowsHitTesting(!isPrimaryActionDisabled)
            .brightness(isPrimaryActionConfirmed ? 0.06 : 0)
            .animation(TrinketMotion.Reward.collectionPulse, value: isPrimaryActionConfirmed)
            .trinketPresentationVisibility(primaryActionOpacity >= 1, opacity: primaryActionOpacity)
            .offset(y: (1 - primaryActionOpacity) * primaryActionEntranceOffset)
            .accessibilityIdentifier(primaryActionAccessibilityIdentifier)
        }
    }
}
