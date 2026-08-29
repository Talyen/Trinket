import SwiftUI
import TrinketContent
import TrinketFeatureSupport

enum LabyrinthNodeArtworkMetrics {
    static let hexFocalZoom: CGFloat = 1.18
    static let combatSourceAspect: CGFloat = 3.0 / 4.0
    static let encounterSourceAspect: CGFloat = 4.0 / 3.0
}

struct LabyrinthHexMetrics {
    let radius: CGFloat
    let hitExpansion: CGFloat = 6
    var width: CGFloat {
        radius * sqrt(3)
    }

    var height: CGFloat {
        radius * 2
    }

    var verticalStep: CGFloat {
        radius * 1.5
    }
}

struct LabyrinthHexagon: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width / sqrt(3), rect.height / 2)
        var path = Path()
        for index in 0 ..< 6 {
            let angle = CGFloat(index) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct LabyrinthFocalImage: View {
    let imageName: String
    let thumbnailName: String?
    let focalPoint: ArtFocalPoint
    var displaySize: Image.PreparedArtworkDisplaySize = .compact
    var sourceAspect: CGFloat = LabyrinthNodeArtworkMetrics.combatSourceAspect
    var zoom: CGFloat = LabyrinthNodeArtworkMetrics.hexFocalZoom

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            let baseScale = max(container.width / sourceAspect, container.height)
            let scale = baseScale * zoom
            let renderedWidth = sourceAspect * scale
            let renderedHeight = scale
            let overflowX = max(renderedWidth - container.width, 0)
            let overflowY = max(renderedHeight - container.height, 0)
            let offsetX = (0.5 - focalPoint.x) * overflowX
            let offsetY = (0.5 - focalPoint.y) * overflowY
            let resolvedName = displaySize == .compact ? (thumbnailName ?? imageName) : imageName
            Image.preparedAsset(named: resolvedName)
                .resizable()
                .interpolation(displaySize == .compact ? .low : .medium)
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .decorativePreparedArtwork()
                .scaleEffect(zoom)
                .offset(x: offsetX, y: offsetY)
        }
        .clipped()
    }
}
