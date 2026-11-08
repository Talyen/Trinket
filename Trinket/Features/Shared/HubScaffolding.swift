import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

enum HubArtworkLayout {
    static let aspectRatio: CGFloat = 1.35

    static func width(in containerSize: CGSize) -> CGFloat {
        min(500, twoCardHeight(in: containerSize) * aspectRatio)
    }

    static func twoCardHeight(in containerSize: CGSize) -> CGFloat {
        let verticalSpacing = TrinketDesign.Layout.compactContentTopPadding
            + TrinketDesign.Spacing.extraLarge + TrinketDesign.Spacing.large
        return max(0, (containerSize.height - verticalSpacing) / 2)
    }
}

private extension EnvironmentValues {
    @Entry var hubArtworkAspectRatio: CGFloat = HubArtworkLayout.aspectRatio
}

struct HubGridScaffold<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let accessibilityIdentifier: String
    var fillsAvailableWidth = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let expandsCards = fillsAvailableWidth && geometry.size.width > 600
            let horizontalPadding = TrinketDesign.Layout.contentMargin * (expandsCards ? 2 : 1)
            let verticalPadding = expandsCards ? TrinketDesign.Spacing.large : 0
            let availableWidth = max(0, geometry.size.width - 2 * horizontalPadding)
            let cardWidth = expandsCards ? availableWidth : HubArtworkLayout.width(in: geometry.size)
            let cardHeight = max(0, HubArtworkLayout.twoCardHeight(in: geometry.size) - verticalPadding)
            let aspectRatio = expandsCards
                ? max(HubArtworkLayout.aspectRatio, availableWidth / max(1, cardHeight))
                : HubArtworkLayout.aspectRatio

            ScrollView {
                LazyVGrid(
                    columns: TrinketDesign.Layout.hubGridItems(for: horizontalSizeClass),
                    spacing: TrinketDesign.Spacing.large,
                ) {
                    content()
                }
                .environment(\.hubArtworkAspectRatio, aspectRatio)
                .frame(maxWidth: cardWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, TrinketDesign.Layout.compactContentTopPadding + verticalPadding)
                .padding(.bottom, TrinketDesign.Spacing.extraLarge + verticalPadding)
            }
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
    let icon: GameIcon?
    let artID: String
    var fallbackArtID: String?
    var isLocked = false
    var aspectRatio: CGFloat = HubArtworkLayout.aspectRatio

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[artID]
            ?? fallbackArtID.flatMap { ArtCatalog.backgroundArtByID[$0] }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    FocalBackgroundArtwork(art: art)
                } else {
                    TrinketDesign.Colors.surface
                }
            }
            .trinketLockedCardEffect(isLocked: isLocked)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                if let subtitle {
                    HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
                        if let icon {
                            GameIconImage(icon)
                                .trinketTypography(.eyebrow)
                                .accessibilityHidden(true)
                        }

                        GameLabel(subtitle, balanced: true)
                            .trinketTypography(.secondaryBody)
                            .trinketFittedText()
                    }
                    .trinketOnArtText(.eyebrow)
                }

                GameLabel(title, balanced: true)
                    .trinketTypography(.screenDisplay)
                    .trinketOnArtText(.title)
                    .trinketFittedText()
            }
            .padding(TrinketDesign.Spacing.large)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
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
    @Environment(\.hubArtworkAspectRatio) private var aspectRatio

    let destination: Destination
    let title: String
    let subtitle: String?
    var icon: GameIcon?
    let artID: String
    var fallbackArtID: String?
    var isLocked = false
    let accessibilityIdentifier: String

    var body: some View {
        NavigationLink(value: destination) {
            HubArtworkCard(
                title: title,
                subtitle: subtitle,
                icon: icon,
                artID: artID,
                fallbackArtID: fallbackArtID,
                isLocked: isLocked,
                aspectRatio: aspectRatio,
            )
        }
        .trinketArtworkCardButtonStyle()
        .disabled(isLocked)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
