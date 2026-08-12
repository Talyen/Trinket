import SwiftUI

/// Segment state for a vertical path connector between circular nodes.
public enum PathConnectorState: Equatable, Sendable {
    case completed
    case progressed
    case future

    /// Before/after connectors for a node in a vertical path of `count` nodes.
    ///
    /// `isFuture` is evaluated at the current index for the before segment and at
    /// `index + 1` for the after segment.
    public static func pair(
        at index: Int,
        count: Int,
        isFuture: (Int) -> Bool
    ) -> (before: Self?, after: Self?) {
        pair(at: index, count: count) { isFuture($0) ? .future : .progressed }
    }

    /// Before/after connectors for a vertical path when each segment's state
    /// is derived from the node it leads into.
    public static func pair(
        at index: Int,
        count: Int,
        state: (Int) -> Self
    ) -> (before: Self?, after: Self?) {
        let before: Self? = index == 0
            ? nil
            : state(index)
        let after: Self? = index >= count - 1
            ? nil
            : state(index + 1)
        return (before, after)
    }
}

/// Colors and widths for completed, progressed, and future connector segments.
public struct PathConnectorStyle: Equatable, Sendable {
    public var completedColor: Color
    public var progressedColor: Color
    public var futureColor: Color
    public var progressedWidth: CGFloat
    public var futureWidth: CGFloat

    public init(
        progressedColor: Color,
        completedColor: Color? = nil,
        futureColor: Color = Color.secondary.opacity(0.38),
        progressedWidth: CGFloat = 3,
        futureWidth: CGFloat = 2
    ) {
        self.completedColor = completedColor ?? progressedColor
        self.progressedColor = progressedColor
        self.futureColor = futureColor
        self.progressedWidth = progressedWidth
        self.futureWidth = futureWidth
    }

    public static let homesteadAccent = Self(
        progressedColor: TrinketDesign.Colors.accent,
        completedColor: TrinketDesign.Colors.success
    )
}

/// Shared geometry and stroke weights for path nodes (stage select, homestead tiers).
public enum PathNodeMetrics {
    public static let size: CGFloat = 48
    public static let railWidth: CGFloat = 54
    public static let standardStrokeWidth: CGFloat = 2
    public static let emphasizedStrokeWidth: CGFloat = 3

    public static func strokeWidth(emphasized: Bool) -> CGFloat {
        emphasized ? emphasizedStrokeWidth : standardStrokeWidth
    }

    public static func glyphFont(emphasized: Bool) -> Font {
        emphasized
            ? .headline.weight(.semibold)
            : .title3.weight(.semibold)
    }
}

/// Circle chrome for a path node: fill, stroke, and a glyph slot.
public struct PathNodeChrome<Glyph: View>: View {
    let size: CGFloat
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let glyph: Glyph

    public init(
        size: CGFloat = PathNodeMetrics.size,
        fill: Color = TrinketDesign.Colors.surface,
        stroke: Color,
        strokeWidth: CGFloat = PathNodeMetrics.standardStrokeWidth,
        @ViewBuilder glyph: () -> Glyph
    ) {
        self.size = size
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.glyph = glyph()
    }

    /// Convenience that resolves stroke weight from shared path-node emphasis.
    public init(
        fill: Color = TrinketDesign.Colors.surface,
        stroke: Color,
        emphasized: Bool,
        @ViewBuilder glyph: () -> Glyph
    ) {
        self.init(
            size: PathNodeMetrics.size,
            fill: fill,
            stroke: stroke,
            strokeWidth: PathNodeMetrics.strokeWidth(emphasized: emphasized),
            glyph: glyph
        )
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(fill)

            Circle()
                .strokeBorder(stroke, lineWidth: strokeWidth)

            glyph
        }
        .frame(width: size, height: size)
    }
}

/// Vertical rail that anchors a circular node and draws before/after connectors
/// to the row edges so adjacent rows form a continuous path.
public struct VerticalPathRail<Node: View>: View {
    let nodeSize: CGFloat
    let minHeight: CGFloat
    let connectorBefore: PathConnectorState?
    let connectorAfter: PathConnectorState?
    let style: PathConnectorStyle
    let node: Node

    public init(
        nodeSize: CGFloat = PathNodeMetrics.size,
        minHeight: CGFloat = 0,
        connectorBefore: PathConnectorState?,
        connectorAfter: PathConnectorState?,
        style: PathConnectorStyle,
        @ViewBuilder node: () -> Node
    ) {
        self.nodeSize = nodeSize
        self.minHeight = minHeight
        self.connectorBefore = connectorBefore
        self.connectorAfter = connectorAfter
        self.style = style
        self.node = node()
    }

    public var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height / 2

            ZStack(alignment: .top) {
                if let connectorBefore {
                    connector(connectorBefore)
                        .frame(height: max(centerY - nodeSize / 2, 0))
                }

                if let connectorAfter {
                    connector(connectorAfter)
                        .frame(height: max(geometry.size.height - centerY - nodeSize / 2, 0))
                        .offset(y: centerY + nodeSize / 2)
                }

                node
                    .frame(width: nodeSize, height: nodeSize)
                    .offset(y: centerY - nodeSize / 2)
            }
            .frame(maxWidth: .infinity)
        }
        // UIStyleCheck: allow - The rail follows the dynamic row height beside path content.
        .frame(minHeight: max(minHeight, nodeSize), maxHeight: .infinity)
    }

    private func connector(_ state: PathConnectorState) -> some View {
        let color: Color
        let width: CGFloat
        switch state {
        case .completed:
            color = style.completedColor
            width = style.progressedWidth
        case .progressed:
            color = style.progressedColor
            width = style.progressedWidth
        case .future:
            color = style.futureColor
            width = style.futureWidth
        }
        // Square ends let the before/after segments meet flush at adjacent row
        // boundaries instead of leaving a gap between their rounded caps.
        return Rectangle()
            .fill(color)
            .frame(width: width)
            .frame(maxWidth: .infinity)
    }
}
