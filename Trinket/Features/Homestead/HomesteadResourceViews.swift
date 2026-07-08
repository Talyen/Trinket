import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState
    let resources: [HomesteadResource]

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    ForEach(resources) { resource in
                        HomesteadResourcePill(
                            resource: resource,
                            balance: homestead.balance(for: resource, roster: roster)
                        )
                    }
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .scrollTargetLayout()
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

struct HomesteadResourcePill: View {
    let resource: HomesteadResource
    let balance: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: resource.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(resource.tint)
                .frame(width: 18)

            Text(resource.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text("\(balance)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .trinketWalletPill()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resource.displayName), \(balance)")
    }
}
