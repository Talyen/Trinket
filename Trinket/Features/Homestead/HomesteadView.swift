import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var homestead: PlayerHomesteadState {
        appState.homestead
    }

    private var roster: PlayerRosterState {
        appState.roster
    }

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: TrinketDesign.Metrics.largeSpacing),
                GridItem(.flexible(), spacing: TrinketDesign.Metrics.largeSpacing)
            ]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        DetailHeroScrollShell(
            title: "Homestead",
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                title: "Homestead",
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.snugSpacing
            ) {
                if let art = ArtCatalog.backgroundArtByID["homestead"]
                    ?? ArtCatalog.backgroundArtByID["wheatField"] {
                    HomesteadFocalArtwork(art: art)
                } else {
                    TrinketDesign.Colors.surface
                }
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.homesteadBodySpacing) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
                    ForEach(HomesteadNodeCategory.allCases) { category in
                        categoryCard(category)
                    }
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            }
            .padding(.top, TrinketDesign.Metrics.sectionHeaderSpacing)
            .padding(.bottom, TrinketDesign.Metrics.tabBarContentClearance)
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
