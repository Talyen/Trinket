import SwiftUI
import TrinketContent
import TrinketFeatureSupport

enum LabyrinthNodeArtworkMetrics {
    static let hexFocalZoom: CGFloat = 1.18
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
                y: center.y + sin(angle) * radius,
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
    var zoom: CGFloat = LabyrinthNodeArtworkMetrics.hexFocalZoom

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            let resolvedName = displaySize == .compact ? (thumbnailName ?? imageName) : imageName
            Image.preparedAsset(named: resolvedName)
                .resizable()
                .interpolation(displaySize == .compact ? .low : .medium)
                .scaledToFill()
                .visualEffect { content, imageGeometry in
                    content
                        .scaleEffect(zoom)
                        .offset(
                            x: (0.5 - focalPoint.x) * max(imageGeometry.size.width * zoom - container.width, 0),
                            y: (0.5 - focalPoint.y) * max(imageGeometry.size.height * zoom - container.height, 0),
                        )
                }
                .frame(width: container.width, height: container.height)
                .decorativePreparedArtwork()
        }
        .clipped()
    }
}
