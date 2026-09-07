import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport

struct HomesteadProjectTile: View {
    let definition: HomesteadNodeDefinition
    let status: HomesteadProjectStatus
    var zoomNamespace: Namespace.ID

    var body: some View {
        NavigationLink(value: HomesteadRoute.node(definition.id)) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                artwork
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: TrinketDesign.Corners.card)
                            .strokeBorder(
                                status.canBuildOrUpgrade ? TrinketDesign.Colors.accent : TrinketDesign.Colors.subtleStroke,
                                lineWidth: status.canBuildOrUpgrade ? 2 : 1,
                            )
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !status.isUnlocked {
                            Image(systemName: "lock.fill")
                                .trinketTypography(.body)
                                .trinketOnArtText()
                                .padding(TrinketDesign.Spacing.medium)
                                .accessibilityHidden(true)
                        }
                    }

                Text(balanced: definition.title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .matchedTransitionSource(id: definition.id, in: zoomNamespace)
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    @ViewBuilder
    private var artwork: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            HomesteadFocalArtwork(art: art, displaySize: .compact)
                .saturation(status.isUnlocked ? 1 : 0.35)
        } else {
            TrinketDesign.Colors.surface
        }
    }
}
