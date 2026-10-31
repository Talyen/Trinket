import SwiftUI

public struct TrinketWalletGrid<Content: View>: View {
    private let columnCount: Int
    private let wrapsToFit: Bool
    private let content: Content

    public init(columnCount: Int = 4, wrapsToFit: Bool = true, @ViewBuilder content: () -> Content) {
        self.columnCount = max(1, columnCount)
        self.wrapsToFit = wrapsToFit
        self.content = content()
    }

    public var body: some View {
        TrinketWalletGridLayout(
            columnCount: columnCount,
            wrapsToFit: wrapsToFit,
            horizontalSpacing: TrinketDesign.Spacing.medium,
            verticalSpacing: TrinketDesign.Spacing.small,
        ) { content }
            .padding(.horizontal, TrinketDesign.Spacing.medium)
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
            .trinketMaterial(.bottomBar)
    }
}

private struct TrinketWalletGridLayout: Layout {
    var columnCount: Int
    var wrapsToFit: Bool
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    struct Cache {
        var idealSizes: [CGSize]
        var proposedWidth: CGFloat?
        var arrangement: Arrangement?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(idealSizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        arrangement(proposal: proposal, subviews: subviews, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let placed = arrangement(proposal: ProposedViewSize(bounds.size), subviews: subviews, cache: &cache)
        for (index, subview) in subviews.enumerated() {
            let frame = placed.frames[index]
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    struct Arrangement {
        var size: CGSize
        var frames: [CGRect]
    }

    private func arrangement(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Arrangement {
        if let arrangement = cache.arrangement, cache.proposedWidth == proposal.width {
            return arrangement
        }
        let result = arrangement(proposal: proposal, subviews: subviews, idealSizes: cache.idealSizes)
        cache.proposedWidth = proposal.width
        cache.arrangement = result
        return result
    }

    private func arrangement(proposal: ProposedViewSize, subviews: Subviews, idealSizes: [CGSize]) -> Arrangement {
        let itemCount = idealSizes.count
        guard itemCount > 0 else { return Arrangement(size: .zero, frames: []) }

        let availableWidth = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil }
        // Flexible wallets wrap before compressing; fixed wallets keep their column count as balances grow.
        var columns = max(1, min(columnCount, itemCount))
        var idealColumnWidths: [CGFloat]
        while true {
            idealColumnWidths = Array(repeating: CGFloat.zero, count: columns)
            for index in 0 ..< itemCount {
                let column = index % columns
                idealColumnWidths[column] = max(idealColumnWidths[column], idealSizes[index].width.rounded(.up))
            }
            guard wrapsToFit, columns > 1, let availableWidth else { break }
            if idealColumnWidths.reduce(0, +) + horizontalSpacing * CGFloat(columns - 1) <= availableWidth {
                break
            }
            columns -= 1
        }
        let rows = (itemCount + columns - 1) / columns
        let columnGaps = horizontalSpacing * CGFloat(columns - 1)

        let idealWidth = idealColumnWidths.reduce(0, +) + columnGaps
        let columnWidths: [CGFloat] = if let availableWidth, !wrapsToFit || availableWidth < idealWidth {
            Array(repeating: max(0, (availableWidth - columnGaps) / CGFloat(columns)), count: columns)
        } else {
            idealColumnWidths
        }

        var rowHeights = Array(repeating: CGFloat(0), count: rows)
        for index in 0 ..< itemCount {
            let row = index / columns
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidths[index % columns], height: nil))
            rowHeights[row] = max(rowHeights[row], measured.height.rounded(.up))
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
