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
    ArtworkAccessory: View
>: View {
    @Environment(OptionsStore.self) private var options
    @Environment(\.isBattleActive) private var isBattleActive

    let presentation: StageSelectRowPresentation<Item>
    let isPrimaryActionDisabled: Bool
    let onArtworkTap: () -> Void
    let onPrimaryAction: () -> Void
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let partyPickerSheet: () -> PartyPickerSheet
    @ViewBuilder let artworkAccessory: () -> ArtworkAccessory

    @State private var actionFeedbackTrigger = 0
    @State private var isPartyPickerPresented = false
    @State private var hasSettled = false

    init(
        presentation: StageSelectRowPresentation<Item>,
        isPrimaryActionDisabled: Bool,
        onArtworkTap: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder artwork: @escaping () -> Artwork,
        @ViewBuilder partyPickerSheet: @escaping () -> PartyPickerSheet,
        @ViewBuilder artworkAccessory: @escaping () -> ArtworkAccessory
    ) {
        self.presentation = presentation
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
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
        }
    }

    private var artworkFrame: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                artworkControl
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay(alignment: .bottomLeading) {
                artworkAccessory()
            }
    }

    @ViewBuilder
    private var artworkControl: some View {
        if presentation.isArtworkInteractive {
            Button(action: onArtworkTap) {
                artwork()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // UIStyleCheck: allow - Encounter artwork is the enemy-detail affordance.
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier(presentation.artworkAccessibilityID)
        } else {
            artwork()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(presentation.artworkAccessibilityID)
        }
    }

    private var footerDock: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
                titleBlock
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: TrinketDesign.Metrics.smallSpacing)

                actionControls
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                titleBlock

                HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
                    Spacer(minLength: 0)

                    actionControls
                }
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        .background(TrinketDesign.Colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(presentation.activeDetailAccessibilityID)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
            Text(presentation.activeEyebrow.uppercased())
                .trinketTypography(.eyebrow)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(presentation.title)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
            if presentation.showsPartyPicker {
                partyPickerButton
            }
            primaryActionButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var primaryActionButton: some View {
        Button {
            actionFeedbackTrigger += 1
            onPrimaryAction()
        } label: {
            Label(presentation.primaryActionTitle, systemImage: presentation.symbolName)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .trinketPrimaryActionButton(
            controlSize: .regular,
            tint: presentation.tint,
            labelColor: TrinketDesign.Colors.Overlay.paper,
            accessibilityIdentifier: presentation.actionAccessibilityID
        )
        .disabled(isPrimaryActionDisabled)
        .trinketSensoryFeedback(
            .selection,
            trigger: actionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
    }

    private var partyPickerButton: some View {
        Button {
            isPartyPickerPresented = true
        } label: {
            Image(systemName: "person.2.fill")
                .trinketTypography(.button)
                .foregroundStyle(.primary)
                // UIStyleCheck: allow - Compact party icon beside the primary CTA without chip chrome.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .trinketQuietTapButtonStyle()
        .disabled(isBattleActive)
        .accessibilityLabel("Party")
        .accessibilityIdentifier(presentation.partyControlAccessibilityID)
    }
}

extension StageSelectActiveCard where ArtworkAccessory == EmptyView {
    init(
        presentation: StageSelectRowPresentation<Item>,
        isPrimaryActionDisabled: Bool,
        onArtworkTap: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder artwork: @escaping () -> Artwork,
        @ViewBuilder partyPickerSheet: @escaping () -> PartyPickerSheet
    ) {
        self.init(
            presentation: presentation,
            isPrimaryActionDisabled: isPrimaryActionDisabled,
            onArtworkTap: onArtworkTap,
            onPrimaryAction: onPrimaryAction,
            artwork: artwork,
            partyPickerSheet: partyPickerSheet,
            artworkAccessory: { EmptyView() }
        )
    }
}

struct StageSelectMetaLine<Item: Identifiable>: View {
    let presentation: StageSelectRowPresentation<Item>

    var body: some View {
        HStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            Text(presentation.mapLabel)
            Text("·")
            Text(presentation.encounterTypeTitle)
                .foregroundStyle(presentation.tint)
            Image(systemName: presentation.symbolName)
                .foregroundStyle(presentation.tint)
        }
        .trinketTypography(.footnote)
        .foregroundStyle(.secondary)
    }
}
