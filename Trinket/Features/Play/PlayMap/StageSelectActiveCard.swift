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

    let presentation: StageSelectRowPresentation<Item>
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
        HStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
            titleBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            actionControls
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
        .background(TrinketDesign.Colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(presentation.activeDetailAccessibilityID)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
            if !presentation.activeEyebrow.isEmpty {
                Text(balanced: presentation.activeEyebrow.uppercased())
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
                    .trinketSingleLineFittedText()
            }

            Text(balanced: presentation.title)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .trinketSingleLineFittedText()
                .accessibilityLabel(presentation.title)
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
            if presentation.showsPartyPicker, !isLockedContent {
                partyPickerButton
            }
            primaryActionButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var primaryActionButton: some View {
        Button {
            if onPrimaryAction() {
                actionFeedbackTrigger &+= 1
            }
        } label: {
            Label {
                Text(isLockedContent ? "Unlock" : presentation.primaryActionTitle)
            } icon: {
                if isLockedContent {
                    Image(systemName: "lock.fill")
                        .scaleEffect(1.15)
                } else {
                    GameIconImage(presentation.icon)
                        .scaleEffect(1.15)
                }
            }
            .trinketTypography(.button)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        }
        .trinketPrimaryActionButton(
            controlSize: .regular,
            tint: isLockedContent ? TrinketDesign.Colors.accent : presentation.tint,
            labelColor: primaryActionLabelColor,
            accessibilityIdentifier: presentation.actionAccessibilityID,
        )
        .accessibilityLabel(isLockedContent ? "Unlock" : presentation.primaryActionTitle)
        .disabled(isPrimaryActionDisabled)
        .trinketSensoryFeedback(
            .selection,
            trigger: actionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
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
        .accessibilityLabel("Party")
        .accessibilityIdentifier(presentation.partyControlAccessibilityID)
    }
}

extension StageSelectActiveCard where ArtworkAccessory == EmptyView {
    init(
        presentation: StageSelectRowPresentation<Item>,
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
    let presentation: StageSelectRowPresentation<Item>

    var body: some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            if !presentation.mapLabel.isEmpty {
                Text(presentation.mapLabel)
                Text("·")
            }
            Text(presentation.encounterTypeTitle)
                .foregroundStyle(presentation.tint)
            GameIconImage(presentation.icon)
                .foregroundStyle(presentation.tint)
                .accessibilityHidden(true)
        }
        .trinketTypography(.footnote)
        .foregroundStyle(.secondary)
    }
}
