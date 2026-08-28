import SwiftUI
import TrinketAppState
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct HomesteadHeroScreen<HeroArt: View, WalletBottomContent: View, Body: View>: View {
    let title: String
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    var walletAnimationNamespace: Namespace.ID?
    var bottomPadding: CGFloat = TrinketDesign.Metrics.tabBarContentClearance
    @ViewBuilder let heroArt: () -> HeroArt
    @ViewBuilder let walletBottomContent: () -> WalletBottomContent
    @ViewBuilder let bodyContent: () -> Body

    init(
        title: String,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
        walletAnimationNamespace: Namespace.ID? = nil,
        bottomPadding: CGFloat = TrinketDesign.Metrics.tabBarContentClearance,
        @ViewBuilder heroArt: @escaping () -> HeroArt,
        @ViewBuilder walletBottomContent: @escaping () -> WalletBottomContent,
        @ViewBuilder bodyContent: @escaping () -> Body
    ) {
        self.title = title
        self.homestead = homestead
        self.roster = roster
        self.walletAnimationNamespace = walletAnimationNamespace
        self.bottomPadding = bottomPadding
        self.heroArt = heroArt
        self.walletBottomContent = walletBottomContent
        self.bodyContent = bodyContent
    }

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
                bottomPadding: TrinketDesign.Metrics.largeSpacing
            ) {
                heroArt()
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.largeSpacing) {
                HomesteadResourceWallet(
                    homestead: homestead,
                    roster: roster,
                    walletAnimationNamespace: walletAnimationNamespace
                )
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)

                walletBottomContent()

                bodyContent()
            }
            .padding(.top, TrinketDesign.Metrics.sectionHeaderSpacing)
            .padding(.bottom, bottomPadding)
        }
    }
}

extension HomesteadHeroScreen where WalletBottomContent == EmptyView {
    init(
        title: String,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
        walletAnimationNamespace: Namespace.ID? = nil,
        bottomPadding: CGFloat = TrinketDesign.Metrics.tabBarContentClearance,
        @ViewBuilder heroArt: @escaping () -> HeroArt,
        @ViewBuilder bodyContent: @escaping () -> Body
    ) {
        self.title = title
        self.homestead = homestead
        self.roster = roster
        self.walletAnimationNamespace = walletAnimationNamespace
        self.bottomPadding = bottomPadding
        self.heroArt = heroArt
        walletBottomContent = { EmptyView() }
        self.bodyContent = bodyContent
    }
}
