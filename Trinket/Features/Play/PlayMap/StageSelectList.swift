import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

struct StageSelectList<Item: Identifiable, Artwork: View, PartyPickerSheet: View>: View {
    let rows: [StageSelectRowPresentation<Item>]
    var rowSpacing: CGFloat = TrinketDesign.Spacing.extraSmall * 2
    var primaryActionLabelColor: Color = TrinketDesign.Colors.Overlay.paper
    let isPrimaryActionDisabled: (Item) -> Bool
    var isLockedContent: (Item) -> Bool = { _ in false }
    let onArtworkTap: (Item) -> Void
    let onPrimaryAction: (Item) -> Bool
    @ViewBuilder let artwork: (Item, _ isActive: Bool) -> Artwork
    @ViewBuilder let partyPickerSheet: (Item) -> PartyPickerSheet

    var body: some View {
        VStack(spacing: rowSpacing - TrinketDesign.Spacing.extraSmall * 2) {
            ForEach(rows) { presentation in
                StageSelectRow(
                    presentation: presentation,
                    isPrimaryActionDisabled: isPrimaryActionDisabled(presentation.item),
                    isLockedContent: isLockedContent(presentation.item),
                    primaryActionLabelColor: primaryActionLabelColor,
                    onArtworkTap: { onArtworkTap(presentation.item) },
                    onPrimaryAction: { onPrimaryAction(presentation.item) },
                    artwork: { artwork(presentation.item, presentation.isActive) },
                    partyPickerSheet: { partyPickerSheet(presentation.item) },
                )
            }
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.medium)
    }
}

private struct StageSelectRow<Item: Identifiable, Artwork: View, PartyPickerSheet: View>: View {
    let presentation: StageSelectRowPresentation<Item>
    let isPrimaryActionDisabled: Bool
    let isLockedContent: Bool
    let primaryActionLabelColor: Color
    let onArtworkTap: () -> Void
    let onPrimaryAction: () -> Bool
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let partyPickerSheet: () -> PartyPickerSheet

    var body: some View {
        Group {
            if presentation.isActive {
                StageSelectActiveCard(
                    presentation: presentation,
                    isPrimaryActionDisabled: isPrimaryActionDisabled,
                    isLockedContent: isLockedContent,
                    primaryActionLabelColor: primaryActionLabelColor,
                    onArtworkTap: onArtworkTap,
                    onPrimaryAction: onPrimaryAction,
                    artwork: artwork,
                    partyPickerSheet: partyPickerSheet,
                    artworkAccessory: { StageSelectModifierCaption(modifiers: presentation.modifiers) },
                )
            } else if presentation.allowsCompactInspection, presentation.isArtworkInteractive {
                Button(action: onArtworkTap) { compactRow }
                    .trinketArtworkCardButtonStyle()
                    .accessibilityIdentifier(presentation.artworkAccessibilityID)
            } else {
                compactRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        .accessibilityIdentifier(presentation.rowAccessibilityID)
    }

    private var compactRow: some View {
        HStack(spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            artwork()
                // UIStyleCheck: allow - Fixed 4:3 thumbnail keeps a linear path compact.
                .frame(width: 74, height: 55.5)
                .clipShape(TrinketDesign.cardShape)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                Text(presentation.title)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                StageSelectMetaLine(presentation: presentation)
                ForEach(presentation.modifiers) { modifier in
                    Text(modifier.title)
                        .trinketTypography(.footnote)
                        .foregroundStyle(modifier.style.color)
                }
            }

            Spacer(minLength: TrinketDesign.Spacing.extraSmall)
        }
        .frame(minHeight: 68)
        .trinketSurface(.denseRow)
        .clipShape(TrinketDesign.cardShape)
        .opacity(0.72)
    }
}
