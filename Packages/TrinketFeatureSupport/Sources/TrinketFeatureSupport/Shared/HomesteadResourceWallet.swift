import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let gold: Int
    let displayedBalances: [HomesteadResource: Int]
    let increaseAnimationDelays: [HomesteadResource: TimeInterval]
    let keepsArtworkStationary: Bool

    public init(
        homestead: PlayerHomesteadState,
        gold: Int,
        displayedBalances: [HomesteadResource: Int] = [:],
        increaseAnimationDelays: [HomesteadResource: TimeInterval] = [:],
        keepsArtworkStationary: Bool = false,
    ) {
        self.homestead = homestead
        self.gold = gold
        self.displayedBalances = displayedBalances
        self.increaseAnimationDelays = increaseAnimationDelays
        self.keepsArtworkStationary = keepsArtworkStationary
    }

    public var body: some View {
        TrinketWalletGrid(columnCount: 4, wrapsToFit: false) {
            ForEach(Array(HomesteadResource.allCases.enumerated()), id: \.element) { index, resource in
                walletPill(for: resource, index: index)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }

    private func walletPill(for resource: HomesteadResource, index: Int) -> some View {
        TrinketWalletResourcePill(
            title: resource.displayName,
            amount: displayedBalances[resource] ?? homestead.balance(for: resource, gold: gold),
            increaseAnimationDelay: increaseAnimationDelays[resource] ?? min(
                Double(index) * TrinketMotion.Interaction.walletIncreaseDelayStep,
                TrinketMotion.Interaction.walletIncreaseMaximumDelay,
            ),
            keepsArtworkStationary: keepsArtworkStationary,
        ) {
            HomesteadResourceArtwork(resource: resource)
                .anchorPreference(key: HomesteadWalletArtworkAnchors.self, value: .bounds) {
                    [resource: $0]
                }
        }
        .accessibilityElement(children: .ignore)
        .gameAccessibilityLabel(resource.displayName)
        .accessibilityValue((displayedBalances[resource] ?? homestead.balance(for: resource, gold: gold)).formatted())
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceBalance(resource))
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
