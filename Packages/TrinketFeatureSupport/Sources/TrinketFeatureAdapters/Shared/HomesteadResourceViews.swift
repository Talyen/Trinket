import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    public init(homestead: PlayerHomesteadState, roster: PlayerRosterState) {
        self.homestead = homestead
        self.roster = roster
    }

    public var body: some View {
        TrinketWalletGrid {
            ForEach(HomesteadResource.allCases) { resource in
                TrinketWalletResourcePill(
                    title: resource.displayName,
                    amount: homestead.balance(for: resource, roster: roster)
                ) {
                    HomesteadResourceArtwork(resource: resource)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }
}
