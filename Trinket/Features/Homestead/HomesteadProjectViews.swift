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
            VStack(alignment: .center, spacing: TrinketDesign.Spacing.small) {
                artwork
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: TrinketDesign.Corners.card)
                            .strokeBorder(
                                TrinketDesign.Colors.subtleStroke,
                                lineWidth: 1,
                            )
                    }
                    .shadow(color: TrinketDesign.Colors.accent.opacity(status.canBuildOrUpgrade ? 0.4 : 0), radius: 8)
                    .overlay(alignment: .bottomTrailing) {
                        if !status.isUnlocked {
                            Image(systemName: "lock.fill")
                                .trinketTypography(.body)
                                .trinketOnArtText()
                                .padding(TrinketDesign.Spacing.medium)
                                .accessibilityHidden(true)
                        }
                    }

                HomesteadTierProgress(currentTier: status.currentTier, totalTiers: definition.maxTier)
                    .frame(maxWidth: 132)
                    .accessibilityHidden(true)

                Text(balanced: definition.title)
                    .trinketTypography(.cardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .matchedTransitionSource(id: definition.id, in: zoomNamespace)
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityValue("\(status.currentTier) of \(definition.maxTier) upgrades")
        .accessibilityIdentifier(AccessibilityID.Homestead.node(title: definition.title))
    }

    @MainActor
    @ViewBuilder
    private var artwork: some View {
        if let art = ArtCatalog.portraitBackgroundArtByID[definition.id.rawValue] {
            FocalBackgroundArtwork(art: art, displaySize: .compact)
                .saturation(status.isUnlocked ? 1 : 0.35)
        } else {
            TrinketDesign.Colors.surface
        }
    }
}
