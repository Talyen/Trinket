import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

struct StageSelectActiveCard<
    Item: Identifiable,
    Artwork: View,
    PartyPickerSheet: View,
    ArtworkAccessory: View,
>: View {
    @Environment(OptionsStore.self) private var options
    @Environment(\.isBattleActive) private var isBattleActive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    let presentation: StageSelectRowPresentation<Item>
    let hapticsEnabledOverride: Bool?
    let isPrimaryActionDisabled: Bool
    let isLockedContent: Bool
    let primaryActionLabelColor: Color
    let onArtworkTap: () -> Void
    let onPrimaryAction: () -> Bool
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let partyPickerSheet: () -> PartyPickerSheet
    @ViewBuilder let artworkAccessory: () -> ArtworkAccessory

    @State private var actionFeedbackTrigger = 0
    @State private var isPartyPickerPresented = false
    @State private var hasSettled = false

    init(
        presentation: StageSelectRowPresentation<Item>,
        hapticsEnabledOverride: Bool? = nil,
        isPrimaryActionDisabled: Bool,
        isLockedContent: Bool = false,
        primaryActionLabelColor: Color = TrinketDesign.Colors.Overlay.paper,
        onArtworkTap: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Bool,
        @ViewBuilder artwork: @escaping () -> Artwork,
        @ViewBuilder partyPickerSheet: @escaping () -> PartyPickerSheet,
        @ViewBuilder artworkAccessory: @escaping () -> ArtworkAccessory,
    ) {
        self.presentation = presentation
        self.hapticsEnabledOverride = hapticsEnabledOverride
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.isLockedContent = isLockedContent
        self.primaryActionLabelColor = primaryActionLabelColor
        self.onArtworkTap = onArtworkTap
        self.onPrimaryAction = onPrimaryAction
        self.artwork = artwork
        self.partyPickerSheet = partyPickerSheet
        self.artworkAccessory = artworkAccessory
    }

    var body: some View {
        VStack(spacing: 0) {
            artworkFrame
            footerDock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
        .scaleEffect(hasSettled ? 1 : 0.985)
        .onAppear {
            withAnimation(TrinketMotion.Interaction.progressArrival) {
                hasSettled = true
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isPartyPickerPresented) {
            partyPickerSheet()
                .trinketSheetSurface()
        }
    }

    private var artworkFrame: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                artworkControl
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .trinketLockedCardEffect(isLocked: isLockedContent)
            }
            .overlay {
                if !presentation.modifiers.isEmpty {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.45),
                            .init(color: TrinketDesign.Colors.Overlay.ink.opacity(0.68), location: 1),
                        ], startPoint: .top, endPoint: .bottom,
                    )
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomLeading) {
                artworkAccessory()
            }
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artworkControl: some View {
        if presentation.isArtworkInteractive, !isLockedContent {
            Button(action: onArtworkTap) {
                artwork()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
            .trinketArtworkCardButtonStyle()
            .accessibilityIdentifier(presentation.artworkAccessibilityID)
        } else {
            artwork()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(presentation.artworkAccessibilityID)
        }
    }

    private var footerDock: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                fittingFooter
            } else {
                HStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
                    titleBlock.frame(maxWidth: .infinity, alignment: .leading)
                    actionControls.fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .background(TrinketDesign.Colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(presentation.activeDetailAccessibilityID)
    }

    private var fittingFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
                titleBlock.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                actionControls.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                titleBlock
                actionControls
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
            if !presentation.activeEyebrow.isEmpty {
                GameLabel(presentation.activeEyebrow, balanced: true)
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
                    .modifier(StageTitleFit())
            }

            GameLabel(presentation.title, resource: presentation.titleResource, balanced: true)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .modifier(StageTitleFit())
                .accessibilityLabel(label(presentation.title, resource: presentation.titleResource))
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
            if presentation.showsPartyPicker, !isLockedContent {
                partyPickerButton
            }
            primaryActionButton
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryActionButton: some View {
        Button {
            if onPrimaryAction() {
                actionFeedbackTrigger &+= 1
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ViewThatFits(in: .horizontal) {
                        primaryActionLabel.fixedSize(horizontal: true, vertical: false)
                        GameLabel(primaryActionTitle, resource: primaryActionResource)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    primaryActionLabel
                }
            }
            .trinketTypography(.button)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        }
        .trinketPrimaryActionButton(
            controlSize: .regular,
            tint: isLockedContent ? TrinketDesign.Colors.accent : presentation.tint,
            labelColor: primaryActionLabelColor,
            accessibilityIdentifier: presentation.actionAccessibilityID,
        )
        .accessibilityLabel(label(primaryActionTitle, resource: primaryActionResource))
        .disabled(isPrimaryActionDisabled)
        .trinketSensoryFeedback(
            .selection,
            trigger: actionFeedbackTrigger,
            enabled: hapticsEnabledOverride ?? options.hapticsEnabled,
        )
    }

    private var primaryActionTitle: String {
        isLockedContent ? String(localized: L10n.ui_stageselectactivecard_unlock_4ac70) : presentation.primaryActionTitle
    }

    private var primaryActionResource: LocalizedStringResource? {
        isLockedContent ? nil : presentation.primaryActionResource
    }

    private func label(_ english: String, resource: LocalizedStringResource?) -> Text {
        if var resource {
            resource.locale = locale
            return Text(verbatim: String(localized: resource))
        }
        return Text(verbatim: ContentCopy.localized(english, locale: locale))
    }

    private var primaryActionLabel: some View {
        Label {
            GameLabel(primaryActionTitle, resource: primaryActionResource)
        } icon: {
            if isLockedContent {
                Image(systemName: "lock.fill").scaleEffect(1.15)
            } else {
                GameIconImage(presentation.icon).scaleEffect(1.15)
            }
        }
    }

    private var partyPickerButton: some View {
        Button {
            isPartyPickerPresented = true
        } label: {
            GameIconImage(.system("person.2.fill"))
                .trinketTypography(.button)
                .foregroundStyle(.primary)
                .scaleEffect(1.15)
                // UIStyleCheck: allow - Compact party icon beside the primary CTA without chip chrome.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .trinketArtworkCardButtonStyle()
        .disabled(isBattleActive)
        .accessibilityLabel(Text(L10n.ui_stageselectactivecard_party_dfa82))
        .accessibilityIdentifier(presentation.partyControlAccessibilityID)
    }
}

extension StageSelectActiveCard where ArtworkAccessory == EmptyView {
    init(
        presentation: StageSelectRowPresentation<Item>,
        hapticsEnabledOverride: Bool? = nil,
        isPrimaryActionDisabled: Bool,
        isLockedContent: Bool = false,
        primaryActionLabelColor: Color = TrinketDesign.Colors.Overlay.paper,
        onArtworkTap: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Bool,
        @ViewBuilder artwork: @escaping () -> Artwork,
        @ViewBuilder partyPickerSheet: @escaping () -> PartyPickerSheet,
    ) {
        self.init(
            presentation: presentation,
            hapticsEnabledOverride: hapticsEnabledOverride,
            isPrimaryActionDisabled: isPrimaryActionDisabled,
            isLockedContent: isLockedContent,
            primaryActionLabelColor: primaryActionLabelColor,
            onArtworkTap: onArtworkTap,
            onPrimaryAction: onPrimaryAction,
            artwork: artwork,
            partyPickerSheet: partyPickerSheet,
            artworkAccessory: { EmptyView() },
        )
    }
}

struct StageSelectMetaLine<Item: Identifiable>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presentation: StageSelectRowPresentation<Item>

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ViewThatFits(in: .horizontal) {
                    standardLine.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                        if !presentation.mapLabel.isEmpty {
                            GameLabel(presentation.mapLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        encounterKind
                    }
                }
            } else {
                standardLine
            }
        }
        .trinketTypography(.footnote)
        .foregroundStyle(.secondary)
    }

    private var standardLine: some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            if !presentation.mapLabel.isEmpty {
                GameLabel(presentation.mapLabel)
                Text("·")
            }
            GameLabel(presentation.encounterTypeTitle, resource: presentation.encounterTypeResource)
                .foregroundStyle(presentation.tint)
            GameIconImage(presentation.icon)
                .foregroundStyle(presentation.tint)
                .accessibilityHidden(true)
        }
    }

    private var encounterKind: some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            GameLabel(presentation.encounterTypeTitle, resource: presentation.encounterTypeResource)
                .fixedSize(horizontal: false, vertical: true)
            GameIconImage(presentation.icon)
                .accessibilityHidden(true)
        }
        .foregroundStyle(presentation.tint)
    }
}

private struct StageTitleFit: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content.trinketSingleLineFittedText()
        }
    }
}
