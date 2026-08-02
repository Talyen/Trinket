import SwiftUI
import TrinketCore
import TrinketDesignSystem

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

enum CombatantCardEffectCategory: String, CaseIterable, Identifiable {
    case stunned
    case frozen
    case death

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .stunned: "Stunned"
        case .frozen: "Frozen"
        case .death: "Death"
        }
    }
}

enum CombatantStatusEffectKind: String, CaseIterable, Identifiable {
    case swirlingStars
    case dizzyRings
    case sparkleDrift
    case frostVeil
    case iceCrystals
    case rimeBloom

    var id: Self {
        self
    }

    var category: CombatantCardEffectCategory {
        switch self {
        case .swirlingStars, .dizzyRings, .sparkleDrift:
            .stunned
        case .frostVeil, .iceCrystals, .rimeBloom:
            .frozen
        }
    }

    var title: String {
        switch self {
        case .swirlingStars: "Swirling Stars"
        case .dizzyRings: "Dizzy Rings"
        case .sparkleDrift: "Sparkle Drift"
        case .frostVeil: "Frost Veil"
        case .iceCrystals: "Ice Crystals"
        case .rimeBloom: "Rime Bloom"
        }
    }

    static func kinds(for category: CombatantCardEffectCategory) -> [Self] {
        allCases.filter { $0.category == category }
    }
}

struct CombatantStatusEffectConfig: Equatable {
    var intensity: CGFloat = 1
    var particleCount: Int = 24
    var tintStrength: CGFloat = 0.35
    var speed: CGFloat = 1

    /// Orbit radius as a fraction of the card's min dimension (Swirling Stars).
    var orbitRadius: CGFloat = 0.42
    /// Number of orbiting stars (Swirling Stars).
    var starCount: Int = 8
    /// Ring count (Dizzy Rings).
    var ringCount: Int = 3
    /// Card wobble amplitude in degrees (Swirling Stars / Dizzy Rings).
    var wobbleDegrees: CGFloat = 2.4
    /// Frost opacity (Frozen variants).
    var frostOpacity: CGFloat = 0.45
    /// Crawl / bloom density 0…1 (Ice Crystals, Rime Bloom).
    var crackDensity: CGFloat = 0.65

    static func defaults(for kind: CombatantStatusEffectKind) -> Self {
        var config = Self()
        switch kind {
        case .swirlingStars:
            config.particleCount = 8
            config.starCount = 8
            config.orbitRadius = 0.42
            config.wobbleDegrees = 2.2
            config.tintStrength = 0
        case .dizzyRings:
            config.ringCount = 3
            config.wobbleDegrees = 2.4
            config.tintStrength = 0
        case .sparkleDrift:
            config.particleCount = 28
            config.tintStrength = 0.2
        case .frostVeil:
            config.frostOpacity = 0.4
            config.tintStrength = 0
            config.particleCount = 14
        case .iceCrystals:
            config.particleCount = 36
            config.frostOpacity = 0.7
            config.crackDensity = 0.8
            config.tintStrength = 0
        case .rimeBloom:
            config.particleCount = 28
            config.frostOpacity = 0.85
            config.crackDensity = 0.55
            config.tintStrength = 0
        }
        return config
    }
}

struct CombatantStatusEffectOverlay: View {
    let kind: CombatantStatusEffectKind
    let config: CombatantStatusEffectConfig
    let progress: CGFloat

    var body: some View {
        let keyword: Keyword = kind.category == .stunned ? .stun : .freeze
        let style = keyword.visualStyle
        let phase = progress * config.speed

        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                switch kind {
                case .swirlingStars:
                    swirlingStars(size: size, style: style, phase: phase)
                case .dizzyRings:
                    dizzyRings(size: size, style: style, phase: phase)
                case .sparkleDrift:
                    sparkleDrift(size: size, style: style, phase: phase)
                case .frostVeil:
                    frostVeil(size: size, style: style, phase: phase)
                case .iceCrystals:
                    frostCrawl(size: size, style: style, phase: phase)
                case .rimeBloom:
                    rimeBloom(size: size, style: style, phase: phase)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }

    private func swirlingStars(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let count = max(config.starCount, 1)
        let radius = min(size.width, size.height) * config.orbitRadius * 0.5

        // Draw in the card's own coordinate space so the orbit sits on upper-center.
        return Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.28)
            let angleBase = phase * .pi * 2
            for index in 0 ..< count {
                let noise = CombatantCardEffectNoise.value(index, salt: 17)
                let angle = angleBase + CGFloat(index) / CGFloat(count) * .pi * 2
                    + noise * 0.35
                let radial = radius * (0.85 + noise * 0.3)
                let point = CGPoint(
                    x: center.x + cos(angle) * radial,
                    y: center.y + sin(angle) * radial
                )
                let starSize = (4 + noise * 5) * config.intensity
                let twinkle = 0.45 + 0.55 * abs(sin(phase * .pi * 4 + noise * .pi * 2))
                drawStar(
                    in: &context,
                    at: point,
                    size: starSize,
                    color: style.color.opacity(twinkle),
                    secondary: style.secondaryColor.opacity(twinkle * 0.7)
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func dizzyRings(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let rings = max(config.ringCount, 1)
        let minDim = min(size.width, size.height)

        return ZStack {
            ForEach(0 ..< rings, id: \.self) { index in
                let fraction = CGFloat(index + 1) / CGFloat(rings + 1)
                let radius = minDim * (0.28 + fraction * 0.28)
                let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                Circle()
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: 1.5 + CGFloat(index) * 0.35,
                            dash: [6, 5 + CGFloat(index)]
                        )
                    )
                    .foregroundStyle(style.color.opacity(0.55 * Double(config.intensity)))
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(Double(phase * 360 * direction * (0.7 + fraction))))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(TrinketDesign.cardShape)
    }

    private func sparkleDrift(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let count = max(config.particleCount, 1)
        let pulse = 0.5 + 0.5 * sin(phase * .pi * 2)
        return ZStack {
            if config.tintStrength > 0 {
                RadialGradient(
                    colors: [
                        style.glowColor.opacity(0.25 * Double(config.tintStrength * config.intensity * pulse)),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(size.width, size.height) * 0.7
                )
                .clipShape(TrinketDesign.cardShape)
            }

            Canvas { context, _ in
                for index in 0 ..< count {
                    let nx = CombatantCardEffectNoise.value(index, salt: 3)
                    let ny = CombatantCardEffectNoise.value(index, salt: 11)
                    let speed = 0.35 + CombatantCardEffectNoise.value(index, salt: 19) * 0.65
                    let life = (phase * speed + ny).truncatingRemainder(dividingBy: 1)
                    let x = nx * size.width
                    let y = size.height * (1.1 - life * 1.25)
                    let sparkle = 0.3 + 0.7 * abs(sin(life * .pi))
                    let diameter = (2 + nx * 3.5) * config.intensity
                    let rect = CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(style.color.opacity(sparkle))
                    )
                    if life > 0.2, life < 0.85 {
                        drawStar(
                            in: &context,
                            at: CGPoint(x: x, y: y),
                            size: diameter * 1.6,
                            color: style.secondaryColor.opacity(sparkle * 0.65),
                            secondary: style.glowColor.opacity(sparkle * 0.4)
                        )
                    }
                }
            }
            .clipShape(TrinketDesign.cardShape)
        }
    }

    private func frostVeil(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let count = max(config.particleCount, 1)
        return ZStack {
            TrinketDesign.cardShape
                .stroke(style.color.opacity(0.55 * Double(config.intensity)), lineWidth: 2)
                .blur(radius: 1.2)

            Canvas { context, _ in
                for index in 0 ..< count {
                    let edge = index % 4
                    let t = CombatantCardEffectNoise.value(index, salt: 7)
                    let pulse = 0.5 + 0.5 * sin(phase * .pi * 2 + t * .pi * 2)
                    let point = switch edge {
                    case 0: CGPoint(x: t * size.width, y: 4 + t * 8)
                    case 1: CGPoint(x: size.width - 4 - t * 8, y: t * size.height)
                    case 2: CGPoint(x: t * size.width, y: size.height - 4 - t * 8)
                    default: CGPoint(x: 4 + t * 8, y: t * size.height)
                    }
                    drawCrystal(
                        in: &context,
                        at: point,
                        size: (5 + t * 7) * config.intensity,
                        rotation: t * .pi + phase * .pi * 0.25,
                        color: style.color.opacity(0.3 + 0.4 * pulse),
                        secondary: style.secondaryColor.opacity(0.35)
                    )
                }
            }
        }
        .clipShape(TrinketDesign.cardShape)
    }

    /// Edge-rooted tendrils that expand slowly inward (roots stay fixed on the rim).
    private func frostCrawl(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let count = max(config.particleCount, 1)
        // Slow sprawl: spend most of the cycle growing length from fixed edge roots.
        let grow = pow(0.5 + 0.5 * sin(phase * .pi * 2 - .pi / 2), 1.35)
        let maxLen = min(size.width, size.height) * (0.12 + config.crackDensity * 0.2)

        return Canvas { context, _ in
            for index in 0 ..< count {
                let along = CombatantCardEffectNoise.value(index, salt: 23)
                let branchNoise = CombatantCardEffectNoise.value(index, salt: 29)
                let length = maxLen * (0.45 + branchNoise * 0.55) * grow * config.intensity
                guard length > 0.5 else { continue }

                let path = frostTendrilPath(
                    index: index,
                    along: along,
                    size: size,
                    length: length
                )
                let opacity = Double(0.25 + 0.45 * grow * config.frostOpacity)
                context.stroke(
                    path,
                    with: .color(style.secondaryColor.opacity(opacity * 0.55)),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    path,
                    with: .color(style.color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .clipShape(TrinketDesign.cardShape)
    }

    /// Small frost flowers along the outer rim — denser, brighter, stay compact.
    private func rimeBloom(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let blooms = max(config.particleCount, 12)
        let reveal = min(max(phase.truncatingRemainder(dividingBy: 1), 0), 1)
        return Canvas { context, _ in
            for index in 0 ..< blooms {
                let along = CombatantCardEffectNoise.value(index, salt: 41)
                let edge = index % 4
                let delay = CGFloat(index % 7) * 0.04
                let local = min(max((reveal - delay) / 0.5, 0), 1)
                // Bloom then settle slightly smaller toward end of local cycle.
                let sizePulse = local < 0.7 ? local / 0.7 : 1 - (local - 0.7) / 0.3 * 0.35
                guard sizePulse > 0.02 else { continue }

                let inset = 6.0
                let center = switch edge {
                case 0: CGPoint(x: along * size.width, y: inset)
                case 1: CGPoint(x: size.width - inset, y: along * size.height)
                case 2: CGPoint(x: along * size.width, y: size.height - inset)
                default: CGPoint(x: inset, y: along * size.height)
                }

                let radius = min(size.width, size.height) * (0.012 + config.crackDensity * 0.022)
                    * sizePulse * config.intensity
                let petals = 5 + index % 3
                var path = Path()
                for petal in 0 ..< petals {
                    let angle = CGFloat(petal) / CGFloat(petals) * .pi * 2 + along
                    let tip = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let side = radius * 0.3
                    let perp = CGVector(dx: -sin(angle), dy: cos(angle))
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: tip.x + perp.dx * side,
                        y: tip.y + perp.dy * side
                    ))
                    path.addLine(to: tip)
                    path.addLine(to: CGPoint(
                        x: tip.x - perp.dx * side,
                        y: tip.y - perp.dy * side
                    ))
                    path.closeSubpath()
                }
                let opacity = Double(0.4 + 0.5 * sizePulse * config.frostOpacity)
                context.fill(path, with: .color(style.color.opacity(opacity * 0.55)))
                context.stroke(
                    path,
                    with: .color(style.secondaryColor.opacity(opacity)),
                    lineWidth: 0.7
                )
            }
        }
        .clipShape(TrinketDesign.cardShape)
    }
}

private func frostTendrilPath(
    index: Int,
    along: CGFloat,
    size: CGSize,
    length: CGFloat
) -> Path {
    let (root, inward) = frostEdgeRoot(edge: index % 4, along: along, size: size)
    let invLen = sqrt(inward.dx * inward.dx + inward.dy * inward.dy)
    let dir = CGVector(dx: inward.dx / invLen, dy: inward.dy / invLen)
    let perp = CGVector(dx: -dir.dy, dy: dir.dx)
    let segments = 4 + index % 3
    var path = Path()
    path.move(to: root)
    for segment in 1 ... segments {
        let t = CGFloat(segment) / CGFloat(segments)
        let sway = (CombatantCardEffectNoise.value(index * 10 + segment, salt: 31) - 0.5)
            * length * 0.22 * t
        let next = CGPoint(
            x: root.x + dir.dx * length * t + perp.dx * sway,
            y: root.y + dir.dy * length * t + perp.dy * sway
        )
        path.addLine(to: next)
        if segment == segments / 2 {
            let sideLen = length * 0.28
            let sideSign = index.isMultiple(of: 2) ? 1.0 : -1.0
            path.move(to: next)
            path.addLine(to: CGPoint(
                x: next.x + perp.dx * sideLen * sideSign + dir.dx * sideLen * 0.3,
                y: next.y + perp.dy * sideLen * sideSign + dir.dy * sideLen * 0.3
            ))
            path.move(to: next)
        }
    }
    return path
}

private func frostEdgeRoot(
    edge: Int,
    along: CGFloat,
    size: CGSize
) -> (CGPoint, CGVector) {
    switch edge {
    case 0:
        (
            CGPoint(x: along * size.width, y: 2),
            CGVector(dx: (along - 0.5) * 0.35, dy: 1)
        )
    case 1:
        (
            CGPoint(x: size.width - 2, y: along * size.height),
            CGVector(dx: -1, dy: (along - 0.5) * 0.35)
        )
    case 2:
        (
            CGPoint(x: along * size.width, y: size.height - 2),
            CGVector(dx: (along - 0.5) * 0.35, dy: -1)
        )
    default:
        (
            CGPoint(x: 2, y: along * size.height),
            CGVector(dx: 1, dy: (along - 0.5) * 0.35)
        )
    }
}

private func drawStar(
    in context: inout GraphicsContext,
    at point: CGPoint,
    size: CGFloat,
    color: Color,
    secondary: Color
) {
    var path = Path()
    let spikes = 4
    for i in 0 ..< (spikes * 2) {
        let angle = CGFloat(i) * .pi / CGFloat(spikes) - .pi / 2
        let radius = i.isMultiple(of: 2) ? size : size * 0.38
        let p = CGPoint(
            x: point.x + cos(angle) * radius,
            y: point.y + sin(angle) * radius
        )
        if i == 0 {
            path.move(to: p)
        } else {
            path.addLine(to: p)
        }
    }
    path.closeSubpath()
    context.fill(path, with: .color(color))
    context.stroke(path, with: .color(secondary), lineWidth: 0.6)
}

private func drawCrystal(
    in context: inout GraphicsContext,
    at point: CGPoint,
    size: CGFloat,
    rotation: CGFloat,
    color: Color,
    secondary: Color
) {
    var path = Path()
    let points: [CGPoint] = [
        CGPoint(x: 0, y: -size),
        CGPoint(x: size * 0.45, y: 0),
        CGPoint(x: 0, y: size * 0.7),
        CGPoint(x: -size * 0.45, y: 0),
    ]
    for (index, local) in points.enumerated() {
        let rotated = CGPoint(
            x: point.x + local.x * cos(rotation) - local.y * sin(rotation),
            y: point.y + local.x * sin(rotation) + local.y * cos(rotation)
        )
        if index == 0 {
            path.move(to: rotated)
        } else {
            path.addLine(to: rotated)
        }
    }
    path.closeSubpath()
    context.fill(path, with: .color(color))
    context.stroke(path, with: .color(secondary), lineWidth: 0.8)
}

/// Card wobble for Swirling Stars and Dizzy Rings.
struct CombatantStatusCardTransform: ViewModifier {
    let kind: CombatantStatusEffectKind
    let config: CombatantStatusEffectConfig
    let progress: CGFloat

    func body(content: Content) -> some View {
        let wobbles = kind == .dizzyRings || kind == .swirlingStars
        let wobble = wobbles
            ? sin(progress * config.speed * .pi * 2) * config.wobbleDegrees * config.intensity
            : 0
        content.rotationEffect(.degrees(Double(wobble)))
    }
}

enum CombatantCardEffectNoise {
    static func value(_ index: Int, salt: Int) -> CGFloat {
        let n = sin(Double(index * 12989 + salt * 78433)) * 43758.5453
        return CGFloat(n - floor(n))
    }
}
#endif
