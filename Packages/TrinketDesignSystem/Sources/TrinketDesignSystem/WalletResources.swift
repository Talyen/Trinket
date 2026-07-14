import SwiftUI

public struct TrinketWalletGrid<Content: View>: View {
    private let columnCount: Int
    private let content: Content

    public init(
        columnCount: Int = 4,
        @ViewBuilder content: () -> Content
    ) {
        self.columnCount = max(1, columnCount)
        self.content = content()
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: TrinketDesign.Metrics.smallSpacing),
            count: columnCount
        )
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            content
        }
        .padding(6)
        .trinketMaterial(.homesteadFooter)
    }
}

public struct TrinketWalletResourcePill<Artwork: View>: View {
    private let title: String
    private let amount: Int
    private let showsIncreasePrefix: Bool
    private let artwork: Artwork

    public init(
        title: String,
        amount: Int,
        showsIncreasePrefix: Bool = false,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.amount = amount
        self.showsIncreasePrefix = showsIncreasePrefix
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artwork
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(showsIncreasePrefix ? "+\(amount)" : "\(amount)")
                    .trinketTypography(.statValue)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .animation(TrinketMotion.Homestead.tierCompletion, value: amount)
    }
}
