import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CardActivationParticles: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let cardSize: CGSize
    let particles: [CardActivationParticle]
    var configuration = CardCastEffectConfiguration()

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for particle in particles {
                let origin = particleOrigin(particle, size: size)
                let distance = configuration.particleDistance
                    + particle.distanceNoise * configuration.particleDistanceVariation
                let delay = particle.delayNoise * configuration.particleDelay
                let lifetimeScale = configuration.particleLifetime
                    + particle.lifetimeNoise * configuration.particleLifetimeVariation
                guard progress >= delay else { continue }
                let age = min((progress - delay) / lifetimeScale, 1)
                guard age < 1 else { continue }
                let easePower = max(configuration.particleAgeEasePower, 0.01)
                let easedAge = 1 - pow(1 - age, easePower)
                let curve = (particle.curveNoise - 0.5)
                    * distance * configuration.particleCurve
                let center = curvedPosition(
                    from: origin,
                    vector: particle.vector,
                    distance: distance,
                    curve: curve,
                    progress: easedAge
                )
                let diameter = (configuration.particleSize
                    + particle.sizeNoise * configuration.particleSizeVariation)
                    * (1 - age * configuration.particleSizeShrink)
                guard diameter > 0.05 else { continue }
                let fadeStart = configuration.fadeStart
                    + particle.fadeNoise * configuration.fadeStartVariation
                let clampedFadeStart = min(max(fadeStart, 0), 0.99)
                let fadeProgress = max(0, (age - clampedFadeStart) / (1 - clampedFadeStart))
                let fadeExponent = max(configuration.particleFadeExponent, 0.01)
                context.opacity = pow(1 - fadeProgress, fadeExponent)
                let colorIndex = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
                let color = keywords[colorIndex].visualStyle.color
                let path = particlePath(
                    shape: configuration.particleShape,
                    center: center,
                    diameter: diameter,
                    vector: particle.vector,
                    sparkLength: configuration.particleSparkLength
                )
                drawParticle(
                    path: path,
                    color: color,
                    style: configuration.particleStyle,
                    diameter: diameter,
                    center: center,
                    in: &context
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawParticle(
        path: Path,
        color: Color,
        style: CardCastParticleStyle,
        diameter: CGFloat,
        center: CGPoint,
        in context: inout GraphicsContext
    ) {
        switch style {
        case .solid:
            context.fill(path, with: .color(color))
        case .outline:
            context.stroke(
                path,
                with: .color(color),
                lineWidth: max(configuration.particleOutlineWidth, 0.25)
            )
        case .softGlow:
            var glowContext = context
            let glowDiameter = diameter * max(configuration.particleGlowScale, 1)
            let glowRect = CGRect(
                x: center.x - glowDiameter / 2,
                y: center.y - glowDiameter / 2,
                width: glowDiameter,
                height: glowDiameter
            )
            glowContext.opacity *= configuration.particleGlowOpacity
            glowContext.fill(Path(ellipseIn: glowRect), with: .color(color))
            context.fill(path, with: .color(color))
        }
    }

    private func particlePath(
        shape: CardCastParticleShape,
        center: CGPoint,
        diameter: CGFloat,
        vector: CGVector,
        sparkLength: CGFloat
    ) -> Path {
        let radius = diameter / 2
        switch shape {
        case .circle:
            return Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: diameter,
                height: diameter
            ))
        case .square:
            return Path(CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: diameter,
                height: diameter
            ))
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
            path.closeSubpath()
            return path
        case .spark:
            let length = max(diameter * max(sparkLength, 0.5), diameter)
            let halfLength = length / 2
            let halfWidth = max(diameter * 0.28, 0.4)
            let angle = atan2(vector.dy, vector.dx)
            let cosA = cos(angle)
            let sinA = sin(angle)
            func point(_ localX: CGFloat, _ localY: CGFloat) -> CGPoint {
                CGPoint(
                    x: center.x + localX * cosA - localY * sinA,
                    y: center.y + localX * sinA + localY * cosA
                )
            }
            var path = Path()
            path.move(to: point(halfLength, 0))
            path.addLine(to: point(0, halfWidth))
            path.addLine(to: point(-halfLength, 0))
            path.addLine(to: point(0, -halfWidth))
            path.closeSubpath()
            return path
        }
    }

    private func particleOrigin(_ particle: CardActivationParticle, size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (particle.originXNoise - 0.5)
                * cardSize.width * configuration.particleOriginSpread,
            y: size.height / 2 + (particle.originYNoise - 0.5)
                * cardSize.height * configuration.particleOriginSpread
        )
    }

    private func curvedPosition(
        from origin: CGPoint,
        vector: CGVector,
        distance: CGFloat,
        curve: CGFloat,
        progress: CGFloat
    ) -> CGPoint {
        let perpendicular = CGVector(dx: -vector.dy, dy: vector.dx)
        let pathControl = min(max(configuration.particlePathControl, 0), 1)
        let end = CGPoint(
            x: origin.x + vector.dx * distance,
            y: origin.y + vector.dy * distance
        )
        let control = CGPoint(
            x: origin.x + vector.dx * distance * pathControl + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * pathControl + perpendicular.dy * curve
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
