import SwiftUI

struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let rows = rows(for: subviews, proposal: ProposedViewSize(width: bounds.width, height: proposal.height))
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if nextWidth > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = FlowRow()
            }

            current.elements.append(FlowElement(index: index, size: size))
            current.width = current.elements.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct FlowRow {
        var elements: [FlowElement] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private struct FlowElement {
        let index: Int
        let size: CGSize
    }
}
