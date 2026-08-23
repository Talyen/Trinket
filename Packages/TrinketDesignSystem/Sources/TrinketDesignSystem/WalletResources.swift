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

    public var body: some View {
        TrinketWalletGridLayout(
            columnCount: columnCount,
            horizontalSpacing: TrinketDesign.Metrics.smallSpacing,
            verticalSpacing: TrinketDesign.Metrics.denseSpacing
        ) {
            content
        }
        .padding(TrinketDesign.Metrics.mediumSpacing)
        .trinketMaterial(.homesteadFooter)
    }
}

public struct TrinketWalletResourcePill<Artwork: View>: View {
    private let title: String
    private let amount: Int
    private let showsIncreasePrefix: Bool
    private let increaseAnimationDelay: TimeInterval
    private let artwork: Artwork
    @State private var increaseAnimationTrigger = 0

    private var displayedAmount: String {
        let value = amount >= 100000
            ? amount.formatted(.number.notation(.compactName))
            : amount.formatted()
        return showsIncreasePrefix ? "+\(value)" : value
    }

    public init(
        title: String,
        amount: Int,
        showsIncreasePrefix: Bool = false,
        increaseAnimationDelay: TimeInterval = 0,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.amount = amount
        self.showsIncreasePrefix = showsIncreasePrefix
        self.increaseAnimationDelay = increaseAnimationDelay
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artwork
                .frame(
                    width: TrinketDesign.Metrics.walletResourceArtworkSize,
                    height: TrinketDesign.Metrics.walletResourceArtworkSize
                )

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                Text(title)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(displayedAmount)
                    .trinketTypography(.statValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
            }
        }
        .frame(
            minHeight: TrinketDesign.Metrics.walletResourceRowMinHeight,
            alignment: .leading
        )
        .animation(TrinketMotion.Homestead.tierCompletion, value: amount)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: increaseAnimationTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            LinearKeyframe(1, duration: increaseAnimationDelay)
            CubicKeyframe(
                TrinketMotion.Interaction.walletIncreaseScale,
                duration: 0.08
            )
            SpringKeyframe(1, duration: 0.18, spring: .smooth)
        }
        .onChange(of: amount) { oldAmount, newAmount in
            guard newAmount > oldAmount else { return }
            increaseAnimationTrigger &+= 1
        }
    }
}

/// Sizes columns to the widest pill, then shrinks only when the proposed width is tighter.
private struct TrinketWalletGridLayout: Layout {
    var columnCount: Int
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrangement(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let placed = arrangement(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = placed.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private struct Arrangement {
        var size: CGSize
        var frames: [CGRect]
    }

    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        let itemCount = subviews.count
        guard itemCount > 0 else {
            return Arrangement(size: .zero, frames: [])
        }

        let columns = max(1, min(columnCount, itemCount))
        let rows = (itemCount + columns - 1) / columns
        let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxItemWidth = (idealSizes.map(\.width).max() ?? 0).rounded(.up)
        let columnGaps = horizontalSpacing * CGFloat(columns - 1)
        var columnWidth = maxItemWidth
        let idealWidth = columnWidth * CGFloat(columns) + columnGaps
        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth < idealWidth {
            columnWidth = max(0, (proposedWidth - columnGaps) / CGFloat(columns))
        }

        var rowHeights = Array(repeating: CGFloat(0), count: rows)
        for index in 0 ..< itemCount {
            rowHeights[index / columns] = max(rowHeights[index / columns], idealSizes[index].height)
        }

        var frames: [CGRect] = []
        frames.reserveCapacity(itemCount)
        var y: CGFloat = 0
        for row in 0 ..< rows {
            var x: CGFloat = 0
            for column in 0 ..< columns {
                let index = row * columns + column
                if index < itemCount {
                    frames.append(CGRect(x: x, y: y, width: columnWidth, height: rowHeights[row]))
                }
                x += columnWidth + horizontalSpacing
            }
            y += rowHeights[row]
            if row < rows - 1 {
                y += verticalSpacing
            }
        }

        let width = columnWidth * CGFloat(columns) + columnGaps
        let height = rowHeights.reduce(0, +) + verticalSpacing * CGFloat(max(rows - 1, 0))
        return Arrangement(size: CGSize(width: width, height: height), frames: frames)
    }
}
