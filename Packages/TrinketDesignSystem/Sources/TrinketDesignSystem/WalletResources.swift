import SwiftUI
import TrinketCore

enum WalletFormatting {
    nonisolated static func displayString(for amount: Int) -> String {
        amount >= 100000 ? amount.formatted(.number.notation(.compactName)) : amount.formatted()
    }
}

extension View {
    func walletIncreaseBump(trigger: Int, delay: TimeInterval = 0) -> some View {
        keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            LinearKeyframe(1, duration: delay)
            CubicKeyframe(TrinketMotion.Interaction.walletIncreaseScale, duration: 0.08)
            SpringKeyframe(1, duration: 0.18, spring: .smooth)
        }
    }
}

public struct TrinketWalletGrid<Content: View>: View {
    private let columnCount: Int
    private let content: Content

    public init(columnCount: Int = 4, @ViewBuilder content: () -> Content) {
        self.columnCount = max(1, columnCount)
        self.content = content()
    }

    public var body: some View {
        TrinketWalletGridLayout(
            columnCount: columnCount,
            horizontalSpacing: TrinketDesign.Spacing.medium,
            verticalSpacing: TrinketDesign.Spacing.small,
        ) { content }
            .padding(.horizontal, TrinketDesign.Spacing.medium)
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
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
        let value = WalletFormatting.displayString(for: amount)
        return showsIncreasePrefix ? "+\(value)" : value
    }

    public init(
        title: String,
        amount: Int,
        showsIncreasePrefix: Bool = false,
        increaseAnimationDelay: TimeInterval = 0,
        @ViewBuilder artwork: () -> Artwork,
    ) {
        self.title = title
        self.amount = amount
        self.showsIncreasePrefix = showsIncreasePrefix
        self.increaseAnimationDelay = increaseAnimationDelay
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            artwork.frame(width: TrinketDesign.Layout.walletResourceArtworkSize, height: TrinketDesign.Layout.walletResourceArtworkSize)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                Text(title).trinketTypography(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.76)

                Text(displayedAmount).trinketTypography(.statValue).lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                    .contentTransition(.numericText())
            }
        }
        .frame(minHeight: TrinketDesign.Layout.walletResourceRowMinHeight, alignment: .leading)
        .animation(TrinketMotion.Interaction.walletIncrease, value: amount)
        .walletIncreaseBump(trigger: increaseAnimationTrigger, delay: increaseAnimationDelay)
        .onChange(of: amount) { oldAmount, newAmount in
            guard newAmount > oldAmount else { return }
            increaseAnimationTrigger &+= 1
        }
    }
}

public struct TrinketCompactResourceChip<Artwork: View>: View {
    private let amount: Int
    private let tint: Color
    private let animationTrigger: Int
    private let artwork: Artwork

    private var displayedAmount: String {
        WalletFormatting.displayString(for: amount)
    }

    public init(amount: Int, tint: Color, animationTrigger: Int = 0, @ViewBuilder artwork: () -> Artwork) {
        self.amount = amount
        self.tint = tint
        self.animationTrigger = animationTrigger
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            artwork
                .frame(width: TrinketDesign.Layout.compactResourceArtworkSize, height: TrinketDesign.Layout.compactResourceArtworkSize)
                .walletIncreaseBump(trigger: animationTrigger)

            Text(displayedAmount).monospacedDigit().contentTransition(.numericText())
        }
        .trinketTypography(.button)
        .foregroundStyle(tint)
        .trinketGlassChip(.emphasis)
        .animation(TrinketMotion.Interaction.stateChange, value: amount)
    }
}

private struct TrinketWalletGridLayout: Layout {
    var columnCount: Int
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrangement(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let placed = arrangement(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = placed.frames[index]
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private struct Arrangement {
        var size: CGSize
        var frames: [CGRect]
    }

    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        let itemCount = subviews.count
        guard itemCount > 0 else { return Arrangement(size: .zero, frames: []) }

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
        let minimumColumnWidth = TrinketDesign.Layout.walletResourceArtworkSize + TrinketDesign.Spacing.small + 16
        let minimumArtworkColumnWidth = TrinketDesign.Layout.walletResourceArtworkSize + TrinketDesign.Spacing.small
        let isUnspecified = proposal.width == nil || proposal.width?.isInfinite == true || (proposal.width ?? 0) < 10

        let columnWidths: [CGFloat]
        if isUnspecified {
            columnWidths = idealColumnWidths.map { max($0, minimumColumnWidth) }
        } else if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth < idealWidth {
            let equalizedWidth = max(minimumArtworkColumnWidth, (proposedWidth - columnGaps) / CGFloat(columns))
            let clampedEqualized = max(minimumColumnWidth, equalizedWidth)
            if clampedEqualized * CGFloat(columns) + columnGaps <= proposedWidth + 0.5 {
                columnWidths = Array(repeating: clampedEqualized, count: columns)
            } else {
                columnWidths = Array(repeating: equalizedWidth, count: columns)
            }
        } else {
            columnWidths = idealColumnWidths.map { max($0, minimumColumnWidth) }
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
