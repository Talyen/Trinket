import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var zoomNamespace

    private var homestead: PlayerHomesteadState {
        appState.homestead
    }

    private var roster: PlayerRosterState {
        appState.roster
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
                    ?? ArtCatalog.backgroundArtByID["wheatField"]
                {
                    HomesteadFocalArtwork(art: art)
                } else {
                    TrinketDesign.Colors.surface
                }
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.homesteadBodySpacing) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                ForEach(HomesteadNodeCategory.allCases) { category in
                    HomesteadProjectSection(
                        category: category,
                        definitions: definitions(in: category),
                        homestead: homestead,
                        roster: roster,
                        zoomNamespace: zoomNamespace
                    )
                }
            }
            .padding(.top, TrinketDesign.Metrics.sectionHeaderSpacing)
            .padding(.bottom, TrinketDesign.Metrics.tabBarContentClearance)
        }
        .navigationDestination(for: HomesteadNodeDefinition.self) { definition in
            HomesteadNodeDetailView(definition: definition)
                .navigationTransition(.zoom(sourceID: definition.id, in: zoomNamespace))
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        GameContent.homesteadNodes.filter { $0.category == category }
    }
}
