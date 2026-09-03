import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct HubArtworkCard: View {
    let title: String
    let subtitle: String?
    let symbolName: String?
    let artID: String
    let fallbackArtID: String
    var isLocked = false

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[artID]
            ?? ArtCatalog.backgroundArtByID[fallbackArtID]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    HomesteadFocalArtwork(art: art)

                } else {
                    TrinketDesign.Colors.surface
                }
            }
            .trinketLockedCardEffect(isLocked: isLocked)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                if let subtitle {
                    HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
                        if let symbolName {
                            Image(systemName: symbolName)
                                .trinketTypography(.eyebrow)
                                .accessibilityHidden(true)
                        }

                        Text(balanced: subtitle)
                            .trinketTypography(.secondaryBody)
                            .trinketFittedText()
                    }
                    .trinketOnArtText(.eyebrow)
                }

                Text(balanced: title)
                    .trinketTypography(.screenDisplay)
                    .trinketOnArtText(.title)
                    .trinketFittedText()
            }
            .padding(TrinketDesign.Spacing.large)
        }
        .aspectRatio(1.35, contentMode: .fit)
        .contentShape(TrinketDesign.cardShape)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
        .shadow(
            color: TrinketDesign.Colors.Overlay.ink.opacity(0.42),
            radius: 12,
            y: 6,
        )
    }
}
