import SwiftUI
import TrinketDesignSystem
import TrinketFeatureAdapters

enum HomesteadTierNodeMetrics {
    static let size: CGFloat = 48
    static let railWidth: CGFloat = 54

    static func strokeWidth(emphasized: Bool) -> CGFloat {
        emphasized ? 3 : 2
    }

    static func glyphFont(emphasized: Bool) -> Font {
        emphasized
            ? .headline.weight(.semibold)
            : .title3.weight(.semibold)
    }
}

struct HomesteadTierNodeChrome<Glyph: View>: View {
    let stroke: Color
    let emphasized: Bool
    @ViewBuilder var glyph: Glyph

    var body: some View {
        ZStack {
            Circle()
                .fill(TrinketDesign.Colors.surface)

            Circle()
                .strokeBorder(
                    stroke,
                    lineWidth: HomesteadTierNodeMetrics.strokeWidth(emphasized: emphasized)
                )

            glyph
        }
        .frame(width: HomesteadTierNodeMetrics.size, height: HomesteadTierNodeMetrics.size)
    }
}

struct HomesteadTierPathRail<Node: View>: View {
    let connectorBefore: HomesteadTierConnectorState?
    let connectorAfter: HomesteadTierConnectorState?
    let connectorBeforeFill: CGFloat?
    let connectorAfterFill: CGFloat?
    let node: Node

    init(
        connectorBefore: HomesteadTierConnectorState?,
        connectorAfter: HomesteadTierConnectorState?,
        connectorBeforeFill: CGFloat? = nil,
        connectorAfterFill: CGFloat? = nil,
        @ViewBuilder node: () -> Node
    ) {
        self.connectorBefore = connectorBefore
        self.connectorAfter = connectorAfter
        self.connectorBeforeFill = connectorBeforeFill
        self.connectorAfterFill = connectorAfterFill
        self.node = node()
    }

    var body: some View {
        GeometryReader { geometry in
            let nodeRadius = HomesteadTierNodeMetrics.size / 2
            // Clamp center to avoid negative offsets during first-layout when
            // the parent has not yet resolved its minHeight (geometry 0).
            let centerY = max(geometry.size.height / 2, nodeRadius)

            ZStack(alignment: .top) {
                if let connectorBefore {
                    connector(connectorBefore, completedFill: connectorBeforeFill)
                        .frame(height: max(centerY - nodeRadius, 0))
                }

                if let connectorAfter {
                    connector(connectorAfter, completedFill: connectorAfterFill)
                        .frame(height: max(geometry.size.height - centerY - nodeRadius, 0))
                        .offset(y: centerY + nodeRadius)
                }

                node
                    .frame(
                        width: HomesteadTierNodeMetrics.size,
                        height: HomesteadTierNodeMetrics.size
                    )
                    .offset(y: centerY - nodeRadius)
            }
            .frame(maxWidth: .infinity)
        }
        // UIStyleCheck: allow - The rail follows the dynamic row height beside path content.
        .frame(minHeight: 72, maxHeight: .infinity)
    }

    @ViewBuilder
    private func connector(
        _ state: HomesteadTierConnectorState,
        completedFill: CGFloat?
    ) -> some View {
        let width: CGFloat = state == .future ? 2 : 2.5
        if state == .completed, let completedFill {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(TrinketDesign.Colors.accent.opacity(0.7))
                    .frame(width: width)
                Rectangle()
                    .fill(TrinketDesign.Colors.success.opacity(0.7))
                    .frame(width: width)
                    .scaleEffect(x: 1, y: min(max(completedFill, 0), 1), anchor: .top)
            }
            .frame(maxWidth: .infinity)
        } else {
            Rectangle()
                .fill(connectorColor(for: state))
                .frame(width: width)
                .frame(maxWidth: .infinity)
        }
    }

    private func connectorColor(for state: HomesteadTierConnectorState) -> Color {
        switch state {
        case .completed: TrinketDesign.Colors.success.opacity(0.7)
        case .progressed: TrinketDesign.Colors.accent.opacity(0.7)
        case .future: Color.secondary.opacity(0.28)
        }
    }
}
