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
        walletAnimationNamespace: Namespace.ID? = nil,
    ) {
        self.homestead = homestead
        self.roster = roster
        self.walletAnimationNamespace = walletAnimationNamespace
    }

    public var body: some View {
        TrinketWalletGrid {
            walletPill(for: .wood, index: 0)
            walletPill(for: .stone, index: 1)
            walletPill(for: .iron, index: 2)
            walletPill(for: .food, index: 3)
            walletPill(for: .herbs, index: 4)
            walletPill(for: .hide, index: 5)
            walletPill(for: .crystal, index: 6)
            walletPill(for: .gold, index: 7)
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }

    private func walletPill(for resource: HomesteadResource, index: Int) -> some View {
        TrinketWalletResourcePill(
            title: resource.displayName,
            amount: homestead.balance(for: resource, roster: roster),
            increaseAnimationDelay: min(
                Double(index) * TrinketMotion.Interaction.walletIncreaseDelayStep,
                TrinketMotion.Interaction.walletIncreaseMaximumDelay,
            ),
        ) {
            walletArtwork(for: resource)
        }
    }

    @ViewBuilder
    private func walletArtwork(for resource: HomesteadResource) -> some View {
        let artwork = HomesteadResourceArtwork(resource: resource)
        if let walletAnimationNamespace {
            artwork.matchedGeometryEffect(
                id: resource.walletAnimationID,
                in: walletAnimationNamespace,
                isSource: false,
            )
        } else {
            artwork
        }
    }
}
