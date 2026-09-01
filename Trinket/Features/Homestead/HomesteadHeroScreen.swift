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
    var bottomPadding: CGFloat = TrinketDesign.Layout.tabBarContentClearance
    @ViewBuilder let heroArt: () -> HeroArt
    @ViewBuilder let walletBottomContent: () -> WalletBottomContent
    @ViewBuilder let bodyContent: () -> Body

    init(
        title: String,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
        walletAnimationNamespace: Namespace.ID? = nil,
        bottomPadding: CGFloat = TrinketDesign.Layout.tabBarContentClearance,
        @ViewBuilder heroArt: @escaping () -> HeroArt,
        @ViewBuilder walletBottomContent: @escaping () -> WalletBottomContent,
        @ViewBuilder bodyContent: @escaping () -> Body,
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
            heroHeightPolicy: .cinematicLandscape,
        ) { baseHeight in
            DetailHeroHeader(
                title: title,
                baseHeight: baseHeight,
                horizontalPadding: TrinketDesign.Layout.contentMargin,
                bottomPadding: TrinketDesign.Spacing.large,
            ) {
                heroArt()
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                HomesteadResourceWallet(
                    homestead: homestead,
                    roster: roster,
                    walletAnimationNamespace: walletAnimationNamespace,
                )
                .padding(.horizontal, TrinketDesign.Layout.contentMargin)

                walletBottomContent()

                bodyContent()
            }
            .padding(.top, TrinketDesign.Layout.sectionHeaderSpacing)
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
        bottomPadding: CGFloat = TrinketDesign.Layout.tabBarContentClearance,
        @ViewBuilder heroArt: @escaping () -> HeroArt,
        @ViewBuilder bodyContent: @escaping () -> Body,
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
