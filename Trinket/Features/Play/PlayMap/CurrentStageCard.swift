import SwiftUI
import TrinketDesignSystem

enum StageSelectActiveCardLayout {
    case standard
    case compact
}

/// Shared active encounter card used by linear Stage Select surfaces.
struct StageSelectActiveCard<Item: Identifiable, Artwork: View, PartyPickerSheet: View>: View {
    @Environment(AppState.self) private var appState

    let presentation: StageSelectRowPresentation<Item>
    let isPrimaryActionDisabled: Bool
    let onArtworkTap: () -> Void
    let onPrimaryAction: () -> Void
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let partyPickerSheet: () -> PartyPickerSheet
    var layout: StageSelectActiveCardLayout = .standard

    @State private var actionFeedbackTrigger = 0
    @State private var isPartyPickerPresented = false

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
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isPartyPickerPresented) {
            partyPickerSheet()
        }
    }

    private var artworkFrame: some View {
        Color.clear
            .aspectRatio(layout == .compact ? 8.0 / 5.0 : 4.0 / 3.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    artworkControl
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .trinketArtworkBlend(layout == .compact ? .bottom(into: .surface) : .none)
                        .clipped()
                }
            }
            .overlay(alignment: .bottomLeading) {
                if layout == .compact {
                    artworkTitleBlock
                        .padding(TrinketDesign.Metrics.mediumSpacing)
                        .allowsHitTesting(false)
                }
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
        Group {
            if layout == .compact {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                    compactDetailBlock

                    actionControls
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: TrinketDesign.Metrics.smallSpacing) {
                        titleBlock
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: TrinketDesign.Metrics.smallSpacing)

                        actionControls
                    }

                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.mediumSpacing) {
                        titleBlock

                        actionControls
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.smallSpacing)
        .padding(layout == .compact ? TrinketDesign.Metrics.smallSpacing : TrinketDesign.Metrics.mediumSpacing)
        .background(TrinketDesign.Colors.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(presentation.activeDetailAccessibilityID)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
            Text(presentation.activeEyebrow.uppercased())
                .trinketTypography(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(presentation.title)
                .trinketTypography(.sectionDisplay)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            ForEach(Array(presentation.activeDetailLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .trinketTypography(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var artworkTitleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            Text(presentation.title)
                .trinketTypography(.sectionDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(presentation.activeEyebrow)
                .trinketTypography(.caption)
                .trinketOnArtText(.eyebrow)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private var compactDetailBlock: some View {
        if let heading = presentation.activeDetailLines.first {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                Text(heading)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)

                ForEach(Array(presentation.activeDetailLines.dropFirst().enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .trinketTypography(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
            enabled: appState.options.hapticsEnabled
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
        .disabled(appState.battle.activeBattle != nil)
        .accessibilityIdentifier(presentation.partyControlAccessibilityID)
    }
}

/// Shared index + encounter meta line for compact future rows.
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
        .trinketTypography(.caption)
        .foregroundStyle(.secondary)
    }
}
