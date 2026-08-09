import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

/// Shared active + future encounter list for linear Stage Select surfaces.
struct StageSelectList<Item: Identifiable, Artwork: View, PartyPickerSheet: View>: View {
    let rows: [StageSelectRowPresentation<Item>]
    let isPrimaryActionDisabled: (Item) -> Bool
    let onArtworkTap: (Item) -> Void
    let onPrimaryAction: (Item) -> Void
    @ViewBuilder let artwork: (Item, _ isActive: Bool) -> Artwork
    @ViewBuilder let partyPickerSheet: (Item) -> PartyPickerSheet

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { presentation in
                StageSelectRow(
                    presentation: presentation,
                    isPrimaryActionDisabled: isPrimaryActionDisabled(presentation.item),
                    onArtworkTap: { onArtworkTap(presentation.item) },
                    onPrimaryAction: { onPrimaryAction(presentation.item) },
                    artwork: { artwork(presentation.item, presentation.isActive) },
                    partyPickerSheet: { partyPickerSheet(presentation.item) }
                )
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
    }
}

private struct StageSelectRow<Item: Identifiable, Artwork: View, PartyPickerSheet: View>: View {
    let presentation: StageSelectRowPresentation<Item>
    let isPrimaryActionDisabled: Bool
    let onArtworkTap: () -> Void
    let onPrimaryAction: () -> Void
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let partyPickerSheet: () -> PartyPickerSheet

    var body: some View {
        Group {
            if presentation.isActive {
                StageSelectActiveCard(
                    presentation: presentation,
                    isPrimaryActionDisabled: isPrimaryActionDisabled,
                    onArtworkTap: onArtworkTap,
                    onPrimaryAction: onPrimaryAction,
                    artwork: artwork,
                    partyPickerSheet: partyPickerSheet
                )
            } else {
                compactRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, TrinketDesign.Metrics.extraSmallSpacing)
        .accessibilityIdentifier(presentation.rowAccessibilityID)
    }

    private var compactRow: some View {
        HStack(spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            artwork()
                // UIStyleCheck: allow - Fixed 4:3 thumbnail keeps a linear path compact.
                .frame(width: 74, height: 55.5)
                .clipShape(TrinketDesign.cardShape)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                Text(presentation.title)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                StageSelectMetaLine(presentation: presentation)
            }

            Spacer(minLength: TrinketDesign.Metrics.extraSmallSpacing)
        }
        .frame(minHeight: 68)
        .trinketSurface(.denseRow)
        .clipShape(TrinketDesign.cardShape)
        .opacity(0.72)
    }
}
