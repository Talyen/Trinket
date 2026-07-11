import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 3 : 4
        return Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: TrinketDesign.Metrics.smallSpacing),
            count: count
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(HomesteadResource.allCases) { resource in
                HomesteadResourcePill(
                    resource: resource,
                    balance: homestead.balance(for: resource, roster: roster)
                )
            }
        }
        .padding(6)
        .trinketMaterial(.homesteadFooter, cornerRadius: TrinketDesign.Corners.compact)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
        .accessibilityLabel("Homestead resources")
    }
}

struct HomesteadResourcePill: View {
    let resource: HomesteadResource
    let balance: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            HomesteadResourceArtwork(resource: resource)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(resource.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("\(balance)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .animation(
            reduceMotion ? TrinketMotion.Homestead.reduceMotion : TrinketMotion.Homestead.tierCompletion,
            value: balance
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resource.displayName), \(balance) available")
    }
}

struct HomesteadResourceArtwork: View {
    let resource: HomesteadResource

    var body: some View {
        if let art = ArtCatalog.resourceArtByID[resource.rawValue] {
            Image(art.imageName)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Image(systemName: resource.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(resource.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}
