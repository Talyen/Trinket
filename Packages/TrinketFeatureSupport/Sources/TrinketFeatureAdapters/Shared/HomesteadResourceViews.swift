import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let walletAnimationNamespace: Namespace.ID?

    public init(
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
        walletAnimationNamespace: Namespace.ID? = nil
    ) {
        self.homestead = homestead
        self.roster = roster
        self.walletAnimationNamespace = walletAnimationNamespace
    }

    public var body: some View {
        TrinketWalletGrid {
            ForEach(HomesteadResource.allCases) { resource in
                TrinketWalletResourcePill(
                    title: resource.displayName,
                    amount: homestead.balance(for: resource, roster: roster)
                ) {
                    walletArtwork(for: resource)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }

    @ViewBuilder
    private func walletArtwork(for resource: HomesteadResource) -> some View {
        let artwork = HomesteadResourceArtwork(resource: resource)
        if let walletAnimationNamespace {
            artwork.matchedGeometryEffect(
                id: resource.walletAnimationID,
                in: walletAnimationNamespace,
                isSource: false
            )
        } else {
            artwork
        }
    }
}
