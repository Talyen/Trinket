import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
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

public struct HomesteadResourceArtwork: View {
    let resource: HomesteadResource

    public init(resource: HomesteadResource) {
        self.resource = resource
    }

    public var body: some View {
        if let art = ArtCatalog.resourceArtByID[resource.rawValue] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFit()
                .decorativePreparedArtwork()

        } else {
            Image(systemName: resource.symbolName)
                .trinketTypography(.button)
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
