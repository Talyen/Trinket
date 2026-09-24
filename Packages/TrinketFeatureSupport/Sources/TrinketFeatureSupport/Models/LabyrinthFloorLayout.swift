import CoreGraphics
import TrinketContent

/// Geometry shared by every node on one Labyrinth floor.
public struct LabyrinthFloorLayout {
    private static let nodeHitExpansion: CGFloat = 6

    public let radius: CGFloat
    public let availableWidth: CGFloat
    public let height: CGFloat

    private let horizontalCenter: CGFloat

    public var hitExpansion: CGFloat {
        Self.nodeHitExpansion
    }

    public var hexWidth: CGFloat {
        radius * sqrt(3)
    }

    public var hexHeight: CGFloat {
        radius * 2
    }

    public var verticalStep: CGFloat {
        radius * 1.5
    }

    public init(nodes: [LabyrinthNode], availableWidth: CGFloat) {
        self.availableWidth = availableWidth
        let positions = nodes.map { $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 0) }
        let halfColumns = nodes.compactMap(\.gridPosition?.projectedHalfColumn)
        let resolvedRadius = LabyrinthMapPresentation.hexRadius(
            forAvailableWidth: availableWidth,
            projectedHalfColumnSpan: (halfColumns.max() ?? 0) - (halfColumns.min() ?? 0),
        )
        radius = resolvedRadius
        let projectedXs = positions.map { position in
            resolvedRadius * sqrt(3) * (CGFloat(position.column) + CGFloat(position.row) / 2)
        }
        horizontalCenter = ((projectedXs.min() ?? 0) + (projectedXs.max() ?? 0)) / 2
        let lastRow = nodes.compactMap(\.gridPosition?.row).max() ?? 0
        height = CGFloat(lastRow) * (resolvedRadius * 1.5)
            + resolvedRadius * 2 + Self.nodeHitExpansion * 2
    }

    public func point(for gridPosition: LabyrinthGridPosition?) -> CGPoint {
        let position = gridPosition ?? LabyrinthGridPosition(row: 0, column: 0)
        let projectedX = radius * sqrt(3) * (
            CGFloat(position.column) + CGFloat(position.row) / 2
        )
        return CGPoint(
            x: availableWidth / 2 + projectedX - horizontalCenter,
            y: CGFloat(position.row) * verticalStep + hexHeight / 2 + hitExpansion,
        )
    }
}
