import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

/// Per-category Homestead list: category hero, wallet, and project rows.
struct HomesteadCategoryView: View {
    let category: HomesteadNodeCategory

    @Environment(PlayerSaveStore.self) private var playerSave
    @Namespace private var zoomNamespace

    private var homestead: PlayerHomesteadState {
        playerSave.homestead
    }

    private var roster: PlayerRosterState {
        playerSave.roster
    }

    private var definitions: [HomesteadNodeDefinition] {
        GameContent.homesteadNodes.filter { $0.category == category }
    }

    var body: some View {
        DetailHeroScrollShell(
            title: category.rawValue,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                title: category.rawValue,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.snugSpacing
            ) {
                categoryHeroArt
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.homesteadBodySpacing) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                HomesteadProjectSection(
                    category: category,
                    definitions: definitions,
                    homestead: homestead,
                    roster: roster,
                    zoomNamespace: zoomNamespace,
                    showsCategoryHeader: false
                )
            }
            .padding(.top, TrinketDesign.Metrics.sectionHeaderSpacing)
            .padding(.bottom, TrinketDesign.Metrics.tabBarContentClearance)
        }
        .navigationDestination(for: HomesteadNodeDefinition.self) { definition in
            HomesteadNodeDetailView(definition: definition)
                .navigationTransition(.zoom(sourceID: definition.id, in: zoomNamespace))
        }
    }

    @ViewBuilder
    private var categoryHeroArt: some View {
        if let art = ArtCatalog.backgroundArtByID[category.artID] {
            HomesteadFocalArtwork(art: art)
        } else {
            TrinketDesign.Colors.surface
        }
    }
}

extension HomesteadNodeCategory {
    /// Background art IDs used by the category cards and category hero.
    var artID: String {
        switch self {
        case .farming: "wheatField"
        case .crafting: "blacksmithForge"
        case .alchemy: "alchemyLab"
        case .training: "hunterLodge"
        case .arcana: "moonlitSanctum"
        }
    }
}
