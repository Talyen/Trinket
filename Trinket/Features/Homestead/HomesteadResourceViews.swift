import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadResourceWallet: View {
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: TrinketDesign.Metrics.smallSpacing),
            count: 4
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
        .trinketMaterial(.homesteadFooter)
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceWallet)
    }
}

struct HomesteadResourcePill: View {
    let resource: HomesteadResource
    let balance: Int

    var body: some View {
        HStack(spacing: 8) {
            HomesteadResourceArtwork(resource: resource)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(resource.displayName)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("\(balance)")
                    .trinketTypography(.statValue)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .animation(TrinketMotion.Homestead.tierCompletion, value: balance)
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
