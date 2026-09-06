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
    let displayedBalances: [HomesteadResource: Int]
    let increaseAnimationDelays: [HomesteadResource: TimeInterval]
    let keepsArtworkStationary: Bool

    public init(
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
        walletAnimationNamespace: Namespace.ID? = nil,
        displayedBalances: [HomesteadResource: Int] = [:],
        increaseAnimationDelays: [HomesteadResource: TimeInterval] = [:],
        keepsArtworkStationary: Bool = false,
    ) {
        self.homestead = homestead
        self.roster = roster
        self.walletAnimationNamespace = walletAnimationNamespace
        self.displayedBalances = displayedBalances
        self.increaseAnimationDelays = increaseAnimationDelays
        self.keepsArtworkStationary = keepsArtworkStationary
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
            amount: displayedBalances[resource] ?? homestead.balance(for: resource, roster: roster),
            increaseAnimationDelay: increaseAnimationDelays[resource] ?? min(
                Double(index) * TrinketMotion.Interaction.walletIncreaseDelayStep,
                TrinketMotion.Interaction.walletIncreaseMaximumDelay,
            ),
            keepsArtworkStationary: keepsArtworkStationary,
        ) {
            walletArtwork(for: resource)
                .anchorPreference(key: HomesteadWalletArtworkAnchors.self, value: .bounds) {
                    [resource: $0]
                }
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

public struct HomesteadWalletArtworkAnchors: PreferenceKey {
    public static var defaultValue: [HomesteadResource: Anchor<CGRect>] {
        [:]
    }

    public static func reduce(
        value: inout [HomesteadResource: Anchor<CGRect>],
        nextValue: () -> [HomesteadResource: Anchor<CGRect>],
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
