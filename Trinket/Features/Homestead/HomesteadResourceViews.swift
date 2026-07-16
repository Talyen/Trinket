import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var body: some View {
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

struct HomesteadResourceArtwork: View {
    let resource: HomesteadResource

    var body: some View {
        if let art = ArtCatalog.resourceArtByID[resource.rawValue] {
            Image(art.imageName)
                .resizable()
                .scaledToFit()

        } else {
            Image(systemName: resource.symbolName)
                .trinketTypography(.button)
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
