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
                HomesteadResourcePill(
                    resource: resource,
                    balance: homestead.balance(for: resource, roster: roster)
                )
            }
        }
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }
}

struct HomesteadResourcePill: View {
    let resource: HomesteadResource
    let balance: Int

    var body: some View {
        TrinketWalletResourcePill(title: resource.displayName, amount: balance) {
            HomesteadResourceArtwork(resource: resource)
        }
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
                .font(.body.weight(.semibold))
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
