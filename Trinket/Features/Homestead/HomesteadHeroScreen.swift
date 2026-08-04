import SwiftUI
import TrinketAppState
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

/// Shared Homestead hero scroll shell: cinematic header, resource wallet, and body content.
struct HomesteadHeroScreen<HeroArt: View, Body: View>: View {
    let title: String
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    var bottomPadding: CGFloat = TrinketDesign.Metrics.tabBarContentClearance
    @ViewBuilder let heroArt: () -> HeroArt
    @ViewBuilder let bodyContent: () -> Body

    var body: some View {
        DetailHeroScrollShell(
            title: title,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                title: title,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.snugSpacing
            ) {
                heroArt()
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.homesteadBodySpacing) {
                HomesteadResourceWallet(homestead: homestead, roster: roster)
                    .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                bodyContent()
            }
            .padding(.top, TrinketDesign.Metrics.sectionHeaderSpacing)
            .padding(.bottom, bottomPadding)
        }
    }
}
