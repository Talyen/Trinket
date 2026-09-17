import SwiftUI
import TrinketDesignSystem

struct RewardCollectionBurstParticle: Sendable {
    let edge: Int // 0: top, 1: right, 2: bottom, 3: left
    let edgeFraction: CGFloat
    let normalOffset: CGFloat
    let speed: CGFloat
    let diameter: CGFloat
    let colorIndex: Int

    static let particles: [Self] = [
        // Top edge
        .init(edge: 0, edgeFraction: 0.15, normalOffset: -0.2, speed: 22, diameter: 3.5, colorIndex: 0),
        .init(edge: 0, edgeFraction: 0.38, normalOffset: 0.1, speed: 28, diameter: 4.0, colorIndex: 1),
        .init(edge: 0, edgeFraction: 0.62, normalOffset: -0.1, speed: 25, diameter: 3.0, colorIndex: 0),
        .init(edge: 0, edgeFraction: 0.85, normalOffset: 0.2, speed: 30, diameter: 4.5, colorIndex: 1),

        // Right edge
        .init(edge: 1, edgeFraction: 0.18, normalOffset: 0.1, speed: 24, diameter: 3.2, colorIndex: 0),
        .init(edge: 1, edgeFraction: 0.40, normalOffset: -0.2, speed: 29, diameter: 4.2, colorIndex: 1),
        .init(edge: 1, edgeFraction: 0.65, normalOffset: 0.2, speed: 26, diameter: 3.0, colorIndex: 0),
        .init(edge: 1, edgeFraction: 0.88, normalOffset: -0.1, speed: 27, diameter: 3.8, colorIndex: 1),

        // Bottom edge
        .init(edge: 2, edgeFraction: 0.20, normalOffset: 0.2, speed: 25, diameter: 3.6, colorIndex: 0),
        .init(edge: 2, edgeFraction: 0.45, normalOffset: -0.1, speed: 32, diameter: 4.2, colorIndex: 1),
        .init(edge: 2, edgeFraction: 0.70, normalOffset: 0.1, speed: 23, diameter: 3.0, colorIndex: 0),
        .init(edge: 2, edgeFraction: 0.88, normalOffset: -0.2, speed: 28, diameter: 4.0, colorIndex: 1),

        // Left edge
        .init(edge: 3, edgeFraction: 0.15, normalOffset: -0.1, speed: 26, diameter: 3.8, colorIndex: 0),
        .init(edge: 3, edgeFraction: 0.38, normalOffset: 0.2, speed: 31, diameter: 4.4, colorIndex: 1),
        .init(edge: 3, edgeFraction: 0.62, normalOffset: -0.2, speed: 24, diameter: 3.2, colorIndex: 0),
        .init(edge: 3, edgeFraction: 0.85, normalOffset: 0.1, speed: 29, diameter: 3.5, colorIndex: 1),
    ]
}

struct RewardCollectionBurstView: View {
    let progress: CGFloat
    let colors: [Color]

    private static let travelPad: CGFloat = 36

    var body: some View {
        Canvas { context, size in
            guard progress > 0.001, progress < 0.999 else { return }

            let cardRect = CGRect(
                x: Self.travelPad,
                y: Self.travelPad,
                width: max(0, size.width - Self.travelPad * 2),
                height: max(0, size.height - Self.travelPad * 2),
            )

            let eased = 1 - pow(1 - progress, 2)
            let opacity = Double(max(0, 1 - progress))
            let resolvedColors = colors.isEmpty
                ? [TrinketDesign.Colors.accent, TrinketDesign.Colors.Overlay.paper]
                : colors

            for particle in RewardCollectionBurstParticle.particles {
                let start = startPoint(for: particle, in: cardRect)
                let dir = direction(for: particle)
                let current = CGPoint(
                    x: start.x + dir.dx * particle.speed * eased,
                    y: start.y + dir.dy * particle.speed * eased,
                )
                let diameter = particle.diameter * (1 - progress * 0.35)
                let rect = CGRect(
                    x: current.x - diameter / 2,
                    y: current.y - diameter / 2,
                    width: diameter,
                    height: diameter,
                )

                let color = resolvedColors[particle.colorIndex % resolvedColors.count]
                var pContext = context
                pContext.opacity = opacity
                pContext.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .padding(-Self.travelPad)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func startPoint(for particle: RewardCollectionBurstParticle, in rect: CGRect) -> CGPoint {
        switch particle.edge {
        case 0: // Top
            CGPoint(
                x: rect.minX + rect.width * particle.edgeFraction,
                y: rect.minY,
            )
        case 1: // Right
            CGPoint(
                x: rect.maxX,
                y: rect.minY + rect.height * particle.edgeFraction,
            )
        case 2: // Bottom
            CGPoint(
                x: rect.minX + rect.width * particle.edgeFraction,
                y: rect.maxY,
            )
        default: // Left
            CGPoint(
                x: rect.minX,
                y: rect.minY + rect.height * particle.edgeFraction,
            )
        }
    }

    private func direction(for particle: RewardCollectionBurstParticle) -> CGVector {
        switch particle.edge {
        case 0: // Outward is up (-y)
            CGVector(dx: particle.normalOffset, dy: -1)
        case 1: // Outward is right (+x)
            CGVector(dx: 1, dy: particle.normalOffset)
        case 2: // Outward is down (+y)
            CGVector(dx: particle.normalOffset, dy: 1)
        default: // Outward is left (-x)
            CGVector(dx: -1, dy: particle.normalOffset)
        }
    }
}
