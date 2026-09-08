import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct HubGridScaffold<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let accessibilityIdentifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Layout.hubGridItems(for: horizontalSizeClass),
                spacing: TrinketDesign.Spacing.large,
            ) {
                content()
            }
            .padding(.horizontal, TrinketDesign.Layout.contentMargin)
            .padding(.top, TrinketDesign.Layout.compactContentTopPadding)
            .padding(.bottom, TrinketDesign.Spacing.extraLarge)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .trinketScreenBackground()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct HubArtworkCard: View {
    let title: String
    let subtitle: String?
    let symbolName: String?
    let artID: String
    var fallbackArtID: String?
    var isLocked = false

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[artID]
            ?? fallbackArtID.flatMap { ArtCatalog.backgroundArtByID[$0] }
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

struct HubArtworkNavigationLink<Destination: Hashable>: View {
    let destination: Destination
    let title: String
    let subtitle: String?
    var symbolName: String?
    let artID: String
    var fallbackArtID: String?
    var isLocked = false
    let accessibilityIdentifier: String

    var body: some View {
        NavigationLink(value: destination) {
            HubArtworkCard(
                title: title,
                subtitle: subtitle,
                symbolName: symbolName,
                artID: artID,
                fallbackArtID: fallbackArtID,
                isLocked: isLocked,
            )
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

enum SpiresProgress {
    static func clampedClearedFloors(highestCleared: Int, floorCount: Int) -> Int {
        min(highestCleared, floorCount)
    }

    static func floorsText(cleared: Int, total: Int) -> String {
        "\(cleared) / \(total) Floors"
    }
}
