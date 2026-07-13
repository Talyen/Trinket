import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CardActivationRequest: Equatable, Identifiable {
    let id: UUID
    let artworkName: String?
    let center: CGPoint
    let size: CGSize
    let rotation: CGFloat
    let verticalTilt: CGFloat
    let scale: CGFloat
    let keywords: [Keyword]
    let particleCount: Int

    init(
        id: UUID = UUID(),
        artworkName: String?,
        center: CGPoint,
        size: CGSize,
        rotation: CGFloat,
        verticalTilt: CGFloat,
        scale: CGFloat,
        keywords: [Keyword],
        particleCount: Int = Int.random(in: 100 ... 200)
    ) {
        self.id = id
        self.artworkName = artworkName
        self.center = center
        self.size = size
        self.rotation = rotation
        self.verticalTilt = verticalTilt
        self.scale = scale
        let uniqueKeywords = keywords.reduce(into: [Keyword]()) { result, keyword in
            guard !result.contains(keyword) else { return }
            result.append(keyword)
        }
        self.keywords = uniqueKeywords.isEmpty ? [.physical] : uniqueKeywords
        self.particleCount = particleCount
    }
}

struct CardCastOverlay: View {
    let request: CardActivationRequest
    let onFinished: () -> Void

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(min(
                timeline.date.timeIntervalSince(startDate) / TrinketMotion.Battle.cardActivationDuration,
                1
            ))
            let dissolveProgress = min(progress / 0.34, 1)
            ZStack {
                BattleAbilityCardFace(artworkName: request.artworkName)
                    .mask {
                        CardDissolveMask(progress: dissolveProgress)
                    }

                CardDissolveEnergyEdge(
                    progress: dissolveProgress,
                    keywords: request.keywords
                )
            }
            .frame(width: request.size.width, height: request.size.height)
            .rotationEffect(.radians(request.rotation), anchor: .bottom)
            .rotation3DEffect(
                .degrees(request.verticalTilt),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.35
            )
            .scaleEffect(request.scale * cardScale(at: progress))
            .overlay {
                CardActivationParticles(
                    progress: progress,
                    keywords: request.keywords,
                    cardSize: request.size,
                    particleCount: request.particleCount
                )
                .frame(width: request.size.width + 360, height: request.size.height + 360)
            }
            .position(x: request.center.x, y: request.center.y)
        }
        .allowsHitTesting(false)
        .onAppear {
            startDate = Date()
        }
        .task {
            try? await Task.sleep(for: .seconds(TrinketMotion.Battle.cardActivationDuration))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    private func cardScale(at progress: CGFloat) -> CGFloat {
        let disappearanceProgress = min(progress / 0.34, 1)
        return 1 - disappearanceProgress * 0.06
    }
}

private struct CardDissolveMask: View {
    let progress: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            CardDissolveGrid.draw(in: &context, size: size) { threshold, _, _ in
                (threshold > progress ? 1 : 0, .primary)
            }
        }
    }
}

private struct CardDissolveEnergyEdge: View {
    let progress: CGFloat
    let keywords: [Keyword]

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            CardDissolveGrid.draw(in: &context, size: size, cellScale: 0.55) { threshold, column, row in
                let distanceFromEdge = threshold - progress
                guard distanceFromEdge > 0, distanceFromEdge < 0.09 else {
                    return (0, .primary)
                }
                let colorNoise = dissolveNoise(column: column, row: row + 173)
                let colorIndex = min(Int(colorNoise * CGFloat(keywords.count)), keywords.count - 1)
                return (
                    1 - distanceFromEdge / 0.09,
                    keywords[colorIndex].visualStyle.color
                )
            }
        }
    }
}

private enum CardDissolveGrid {
    private static let cellSize: CGFloat = 4

    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        cellScale: CGFloat = 1,
        style: (_ threshold: CGFloat, _ column: Int, _ row: Int) -> (opacity: CGFloat, color: Color)
    ) {
        let columns = Int(ceil(size.width / cellSize))
        let rows = Int(ceil(size.height / cellSize))
        let maximumInset = max(min(size.width, size.height) / 2, 1)

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let midpoint = CGPoint(
                    x: (CGFloat(column) + 0.5) * cellSize,
                    y: (CGFloat(row) + 0.5) * cellSize
                )
                let inset = min(
                    min(midpoint.x, size.width - midpoint.x),
                    min(midpoint.y, size.height - midpoint.y)
                )
                let edgeDepth = max(0, inset / maximumInset)
                let noise = dissolveNoise(column: column, row: row)
                let threshold = min(edgeDepth * 0.86 + noise * 0.18, 1)
                let cellStyle = style(threshold, column, row)
                let cellOpacity = cellStyle.opacity
                guard cellOpacity > 0 else { continue }

                let renderedCellSize = cellSize * cellScale
                let cellInset = (cellSize - renderedCellSize) / 2
                context.opacity = cellOpacity
                context.fill(
                    Path(CGRect(
                        x: CGFloat(column) * cellSize + cellInset,
                        y: CGFloat(row) * cellSize + cellInset,
                        width: renderedCellSize + 0.5,
                        height: renderedCellSize + 0.5
                    )),
                    with: .color(cellStyle.color)
                )
            }
        }
    }
}

private struct CardActivationParticles: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let cardSize: CGSize
    let particleCount: Int

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for index in 0 ..< particleCount {
                let origin = particleOrigin(index: index, size: size)
                let vector = launchVector(index: index)
                let distance = 96 + dissolveNoise(column: index, row: 53) * 120
                let delay = dissolveNoise(column: index, row: 61) * 0.24
                let lifetimeScale = 0.58 + dissolveNoise(column: index, row: 67) * 0.18
                guard progress >= delay else { continue }
                let age = min((progress - delay) / lifetimeScale, 1)
                guard age < 1 else { continue }
                let easedAge = 1 - pow(1 - age, 2)
                let curve = (dissolveNoise(column: index, row: 83) - 0.5) * distance * 1.15
                let center = curvedPosition(
                    from: origin,
                    vector: vector,
                    distance: distance,
                    curve: curve,
                    progress: easedAge
                )
                let diameter = (1.2 + dissolveNoise(column: index, row: 79) * 5.6) * (1 - age * 0.38)
                let rect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                let fadeStart = 0.32 + dissolveNoise(column: index, row: 101) * 0.5
                let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
                context.opacity = pow(1 - fadeProgress, 1.35)
                let colorNoise = dissolveNoise(column: index, row: 109)
                let colorIndex = min(Int(colorNoise * CGFloat(keywords.count)), keywords.count - 1)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(keywords[colorIndex].visualStyle.color)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func particleOrigin(index: Int, size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (dissolveNoise(column: index, row: 13) - 0.5) * cardSize.width * 0.22,
            y: size.height / 2 + (dissolveNoise(column: index, row: 29) - 0.5) * cardSize.height * 0.22
        )
    }

    private func launchVector(index: Int) -> CGVector {
        let angle = dissolveNoise(column: index, row: 41) * 2 * .pi
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private func curvedPosition(
        from origin: CGPoint,
        vector: CGVector,
        distance: CGFloat,
        curve: CGFloat,
        progress: CGFloat
    ) -> CGPoint {
        let perpendicular = CGVector(dx: -vector.dy, dy: vector.dx)
        let end = CGPoint(
            x: origin.x + vector.dx * distance,
            y: origin.y + vector.dy * distance
        )
        let control = CGPoint(
            x: origin.x + vector.dx * distance * 0.45 + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * 0.45 + perpendicular.dy * curve
        )
        let remaining = 1 - progress
        return CGPoint(
            x: remaining * remaining * origin.x
                + 2 * remaining * progress * control.x
                + progress * progress * end.x,
            y: remaining * remaining * origin.y
                + 2 * remaining * progress * control.y
                + progress * progress * end.y
        )
    }
}

private func dissolveNoise(column: Int, row: Int) -> CGFloat {
    let value = sin(Double(column * 12989 + row * 78233)) * 43758.545_3
    return CGFloat(value - floor(value))
}
