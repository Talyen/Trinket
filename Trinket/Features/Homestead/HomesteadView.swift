import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadView: View {
    @Environment(AppState.self) private var appState

    private var homestead: PlayerHomesteadState {
        appState.homestead.current
    }

    private var roster: PlayerRosterState {
        appState.roster.current
    }

    var body: some View {
        DetailHeroScrollShell(
            title: "Homestead",
            backgroundMode: .homestead,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            HomesteadOverviewHero(baseHeight: baseHeight, overscroll: overscroll)
        } bodyContent: {
            VStack(alignment: .leading, spacing: 18) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                ForEach(HomesteadNodeCategory.allCases) { category in
                    HomesteadProjectSection(
                        category: category,
                        definitions: definitions(in: category),
                        homestead: homestead,
                        roster: roster
                    )
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
        .navigationDestination(for: HomesteadNodeDefinition.self) { definition in
            HomesteadNodeDetailView(definition: definition)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.homestead)
    }

    private func definitions(in category: HomesteadNodeCategory) -> [HomesteadNodeDefinition] {
        GameContent.homesteadNodes.filter { $0.category == category }
    }
}

struct HomesteadOverviewHero: View {
    let baseHeight: CGFloat
    let overscroll: CGFloat

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID["homestead"]
            ?? ArtCatalog.backgroundArtByID["wheatField"]
    }

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .bottomLeading
        ) {
            if let art {
                HomesteadFocalArtwork(art: art)

            } else {
                TrinketDesign.Colors.surface
            }
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                TrinketHeroScrim.gradient(
                    for: .homesteadOverview,
                    startPoint: .init(x: 0.5, y: 0.42),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text("Homestead")
                    .trinketTypography(.screenDisplay)
                    .trinketOnArtText(.title)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                    .padding(.bottom, 14)
            }
        }
    }
}
