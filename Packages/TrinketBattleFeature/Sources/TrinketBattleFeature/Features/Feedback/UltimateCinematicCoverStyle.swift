import SwiftUI
import TrinketDesignSystem

public enum UltimateCinematicCoverStyle: String, CaseIterable, Identifiable, Sendable {
    case diagonalSplit
    case fade

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .diagonalSplit: "Diagonal Split"
        case .fade: "Fade"
        }
    }
}

struct UltimateCinematicCoverView: View {
    let style: UltimateCinematicCoverStyle
    let progress: CGFloat

    var body: some View {
        switch style {
        case .diagonalSplit:
            DiagonalCinematicSplitCover(progress: progress)
        case .fade:
            FadeCinematicCover(progress: progress)
        }
    }
}

struct DiagonalCinematicSplitCover: View {
    var progress: CGFloat

    private static let angleDegrees: CGFloat = 40
    private static let travelFactor: CGFloat = 0.6

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let travel = max(size.width, size.height) * Self.travelFactor
            let angle = Self.angleDegrees * .pi / 180
            let normal = CGVector(dx: cos(angle), dy: -sin(angle))
            let offset = travel * progress
            coverLayers(normal: normal, offset: offset)
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func coverLayers(normal: CGVector, offset: CGFloat) -> some View {
        let primaryOffset = CGSize(width: -normal.dx * offset, height: -normal.dy * offset)
        let secondaryOffset = CGSize(width: normal.dx * offset, height: normal.dy * offset)
        ZStack {
            halfPlane(isPrimary: true)
                .offset(primaryOffset)
            halfPlane(isPrimary: false)
                .offset(secondaryOffset)
        }
    }

    private func halfPlane(isPrimary: Bool) -> some View {
        DiagonalCinematicHalfPlane(isPrimary: isPrimary, angleDegrees: Self.angleDegrees)
            .fill(TrinketDesign.Colors.Overlay.cinematicDim)
    }
}

struct DiagonalCinematicHalfPlane: Shape {
    var isPrimary: Bool
    var angleDegrees: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle = angleDegrees * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let along = CGVector(dx: sin(angle), dy: cos(angle))
        let normal = CGVector(dx: cos(angle), dy: -sin(angle))
        let extent = max(rect.width, rect.height) * 2.2
        let a = CGPoint(x: center.x - along.dx * extent, y: center.y - along.dy * extent)
        let b = CGPoint(x: center.x + along.dx * extent, y: center.y + along.dy * extent)
        let sign: CGFloat = isPrimary ? -1 : 1
        let c = CGPoint(x: b.x + normal.dx * extent * sign, y: b.y + normal.dy * extent * sign)
        let d = CGPoint(x: a.x + normal.dx * extent * sign, y: a.y + normal.dy * extent * sign)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }
}

struct FadeCinematicCover: View {
    var progress: CGFloat

    var body: some View {
        Rectangle()
            .fill(TrinketDesign.Colors.Overlay.cinematicDim)
            .opacity(Double(1.0 - progress))
    }
}
