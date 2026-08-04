import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    var body: some View {
        HomesteadHeroScreen(
            title: "Homestead",
            homestead: homestead,
            roster: roster
        ) {
            if let art = ArtCatalog.backgroundArtByID["homestead"]
                ?? ArtCatalog.backgroundArtByID["wheatField"] {
                HomesteadFocalArtwork(art: art)
            } else {
                TrinketDesign.Colors.surface
            }
        } bodyContent: {
            LazyVGrid(
                columns: TrinketDesign.Metrics.hubGridItems(for: horizontalSizeClass),
                spacing: TrinketDesign.Metrics.largeSpacing
            ) {
                ForEach(HomesteadNodeCategory.allCases) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        }
        .navigationDestination(for: HomesteadNodeCategory.self) { category in
            HomesteadCategoryView(category: category)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
    }

    private func categoryCard(_ category: HomesteadNodeCategory) -> some View {
        let progress = HomesteadCategoryProgress(category: category, homestead: homestead)
        return NavigationLink(value: category) {
            PlayModeArtworkCard(
                title: category.rawValue,
                subtitle: progress.subtitle,
                symbolName: "hammer.fill",
                artID: category.artID,
                fallbackArtID: category.artID
            )
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(AccessibilityID.Homestead.category(category.rawValue))
    }
}
