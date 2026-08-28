import SwiftUI
import TrinketCore

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
            horizontalSpacing: TrinketDesign.Metrics.mediumSpacing,
            verticalSpacing: TrinketDesign.Metrics.smallSpacing
        ) {
            content
        }
        .padding(.horizontal, TrinketDesign.Metrics.mediumSpacing)
        .padding(.vertical, TrinketDesign.Metrics.smallSpacing)
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
        .animation(TrinketMotion.Interaction.walletIncrease, value: amount)
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

/// Compact horizontal resource balance for toolbars and buy chips.
public struct TrinketCompactResourceChip<Artwork: View>: View {
    private let amount: Int
    private let tint: Color
    private let animationTrigger: Int
    private let artwork: Artwork

    private var displayedAmount: String {
        amount >= 100000
            ? amount.formatted(.number.notation(.compactName))
            : amount.formatted()
    }

    public init(
        amount: Int,
        tint: Color,
        animationTrigger: Int = 0,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.amount = amount
        self.tint = tint
        self.animationTrigger = animationTrigger
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artwork
                .frame(
                    width: TrinketDesign.Metrics.compactResourceArtworkSize,
                    height: TrinketDesign.Metrics.compactResourceArtworkSize
                )
                .keyframeAnimator(
                    initialValue: CGFloat(1),
                    trigger: animationTrigger
                ) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.08, duration: 0.08)
                    SpringKeyframe(1, duration: 0.18, spring: .smooth)
                }

            Text(displayedAmount)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .trinketTypography(.button)
        .foregroundStyle(tint)
        .trinketGlassChip(.emphasis)
        .animation(TrinketMotion.Interaction.stateChange, value: amount)
    }
}

/// Sizes columns to fit subview widths, equalizing across columns when constrained by proposed width.
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
        let columnGaps = horizontalSpacing * CGFloat(columns - 1)

        var idealColumnWidths = Array(repeating: CGFloat(0), count: columns)
        for index in 0 ..< itemCount {
            let column = index % columns
            idealColumnWidths[column] = max(idealColumnWidths[column], idealSizes[index].width.rounded(.up))
        }

        let idealWidth = idealColumnWidths.reduce(0, +) + columnGaps
        let columnWidths: [CGFloat]
        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth < idealWidth {
            let equalizedWidth = max(0, (proposedWidth - columnGaps) / CGFloat(columns))
            columnWidths = Array(repeating: equalizedWidth, count: columns)
        } else {
            columnWidths = idealColumnWidths
        }

        var rowHeights = Array(repeating: CGFloat(0), count: rows)
        for index in 0 ..< itemCount {
            let row = index / columns
            rowHeights[row] = max(rowHeights[row], idealSizes[index].height)
        }

        var frames: [CGRect] = []
        frames.reserveCapacity(itemCount)
        var y: CGFloat = 0
        for row in 0 ..< rows {
            var x: CGFloat = 0
            for column in 0 ..< columns {
                let index = row * columns + column
                if index < itemCount {
                    frames.append(CGRect(x: x, y: y, width: columnWidths[column], height: rowHeights[row]))
                }
                x += columnWidths[column] + horizontalSpacing
            }
            y += rowHeights[row]
            if row < rows - 1 {
                y += verticalSpacing
            }
        }

        let totalWidth = columnWidths.reduce(0, +) + columnGaps
        let totalHeight = rowHeights.reduce(0, +) + verticalSpacing * CGFloat(max(rows - 1, 0))
        return Arrangement(size: CGSize(width: totalWidth, height: totalHeight), frames: frames)
    }
}
