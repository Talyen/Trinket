import SwiftUI
import TrinketCore
import TrinketDesignSystem

enum CombatantStatusEffectKind: String, CaseIterable, Identifiable {
    case swirlingStars
    case iceCrystals

    var id: Self {
        self
    }

    init?(statusKeyword: Keyword) {
        switch statusKeyword {
        case .stun:
            self = .swirlingStars
        case .freeze:
            self = .iceCrystals
        default:
            return nil
        }
    }

    func progress(after elapsed: TimeInterval) -> CGFloat {
        CGFloat(
            elapsed / BattleMotion.combatantStatusEffectPhaseDuration,
        )
    }
}

struct CombatantStatusEffectConfig: Equatable {
    var intensity: CGFloat = 1
    var particleCount: Int = 24
    var tintStrength: CGFloat = 0.35
    var speed: CGFloat = 1

    var orbitRadius: CGFloat = 0.42
    var starCount: Int = 8
    var wobbleDegrees: CGFloat = 2.4
    var frostOpacity: CGFloat = 0.45
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
        case .iceCrystals:
            config.intensity = 1.18
            config.particleCount = 16
            config.frostOpacity = 0.9
            config.crackDensity = 0.76
            config.tintStrength = 0
        }
        return config
    }
}

struct CombatantStatusEffectOverlay: View {
    let kind: CombatantStatusEffectKind
    let config: CombatantStatusEffectConfig
    let progress: CGFloat

    private static let productionStarNoise = starNoise(
        count: CombatantStatusEffectConfig.defaults(for: .swirlingStars).starCount,
    )
    private static let productionSnowflakeNoise = snowflakeNoise(
        count: CombatantStatusEffectConfig.defaults(for: .iceCrystals).particleCount,
    )

    private static func starNoise(count: Int) -> [CGFloat] {
        (0 ..< count).map { CombatantCardEffectNoise.value($0, salt: 17) }
    }

    private static func snowflakeNoise(count: Int) -> [(along: CGFloat, inset: CGFloat)] {
        (0 ..< count).map {
            (
                along: CombatantCardEffectNoise.value($0, salt: 41),
                inset: CombatantCardEffectNoise.value($0, salt: 47),
            )
        }
    }

    var body: some View {
        let keyword: Keyword = switch kind {
        case .swirlingStars: .stun
        case .iceCrystals: .freeze
        }
        let style = keyword.visualStyle
        let phase = progress * config.speed

        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                switch kind {
                case .swirlingStars:
                    swirlingStars(size: size, style: style, phase: phase)
                case .iceCrystals:
                    iceCrystals(size: size, style: style, phase: phase)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }

    private func swirlingStars(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let count = max(config.starCount, 1)
        let noiseValues = count == Self.productionStarNoise.count
            ? Self.productionStarNoise
            : Self.starNoise(count: count)
        let radius = min(size.width, size.height) * config.orbitRadius * 0.5
        let appear = min(max(phase / 0.12, 0), 1)

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.28)
        let angleBase = phase * .pi * 2
        var stars: [(point: CGPoint, size: CGFloat, rotation: CGFloat, opacity: Double, sinAngle: CGFloat)] = []
        stars.reserveCapacity(count)

        for index in 0 ..< count {
            let noise = noiseValues[index]
            let angle = angleBase + CGFloat(index) / CGFloat(count) * .pi * 2
                + noise * 0.35
            let radial = radius * (0.85 + noise * 0.3)
            let sinAngle = sin(angle)
            let depth = (sinAngle + 1) * 0.5
            let depthScale = 0.75 + 0.35 * depth
            let depthOpacity = 0.75 + 0.25 * depth
            let baseSize = (6 + noise * 5) * config.intensity
            let twinkle = 0.45 + 0.55 * abs(sin(phase * .pi * 4 + noise * .pi * 2))
            stars.append((
                point: CGPoint(
                    x: center.x + cos(angle) * radial,
                    y: center.y + sinAngle * (radial * 0.38),
                ),
                size: baseSize * depthScale,
                rotation: phase * .pi * 1.5 + noise * .pi * 2,
                opacity: appear > 0.01 ? Double(twinkle * depthOpacity * appear) : 0,
                sinAngle: sinAngle,
            ))
        }
        stars.sort { $0.sinAngle < $1.sinAngle }

        var particles: [Float] = []
        particles.reserveCapacity(count * 5)
        for star in stars {
            particles.append(contentsOf: [
                Float(star.point.x), Float(star.point.y), Float(star.size),
                Float(star.rotation.truncatingRemainder(dividingBy: .pi * 2)), Float(star.opacity),
            ])
        }

        return Rectangle()
            .fill(ShaderLibrary.bundle(.module).combatStunStars(
                .floatArray(particles),
                .color(style.color),
                .color(style.secondaryColor),
                .color(TrinketDesign.Colors.Overlay.ink),
                .color(TrinketDesign.Colors.Overlay.paper),
            ))
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
    }

    private func iceCrystals(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let flakes = max(config.particleCount, 1)
        let encroach = min(
            max(phase / CGFloat(BattleMotion.combatantFreezeEncroachProgress), 0),
            1,
        )
        let onset = min(
            max(phase / CGFloat(BattleMotion.combatantFreezeOnsetProgress), 0),
            1,
        )
        let onsetGlow = sin(onset * .pi)
        let minDim = min(size.width, size.height)
        let clearRadius = minDim * 0.55 * (1 - encroach * (0.55 + config.crackDensity * 0.3))
        let edgeRadius = minDim * 0.78
        let pulse = encroach >= 1
            ? 0.88 + 0.12 * (0.5 + 0.5 * sin(phase * .pi * 2))
            : 1
        let veilOpacity = Double(encroach * config.frostOpacity * config.intensity * pulse)

        return ZStack {
            RadialGradient(
                colors: [
                    Color.clear,
                    style.glowColor.opacity(0.08 * veilOpacity),
                    style.color.opacity(0.22 * veilOpacity),
                    style.secondaryColor.opacity(0.40 * veilOpacity),
                ],
                center: .center,
                startRadius: max(clearRadius, 0),
                endRadius: max(edgeRadius, clearRadius + 1),
            )

            TrinketDesign.cardShape
                .strokeBorder(
                    style.color.opacity(0.34 * veilOpacity),
                    lineWidth: 1.5,
                )

            if onsetGlow > 0.001 {
                TrinketDesign.cardShape
                    .strokeBorder(
                        style.color.opacity(0.34 * Double(onsetGlow)),
                        lineWidth: 2,
                    )
                    .blur(radius: 1.4)
            }

            snowflakeLayer(
                size: size,
                style: style,
                phase: phase,
                flakes: flakes,
                encroach: encroach,
            )
        }
        .clipShape(TrinketDesign.cardShape)
    }

    private func snowflakeLayer(
        size: CGSize,
        style: Keyword.VisualStyle,
        phase: CGFloat,
        flakes: Int,
        encroach: CGFloat,
    ) -> some View {
        let noiseValues = flakes == Self.productionSnowflakeNoise.count
            ? Self.productionSnowflakeNoise
            : Self.snowflakeNoise(count: flakes)
        let radiusFraction: CGFloat = min(size.width, size.height)
            * (0.01 + config.crackDensity * 0.018)
        return Canvas { context, _ in
            for index in 0 ..< flakes {
                let along = noiseValues[index].along
                let edge = index % 4
                let delay = CGFloat(index) / CGFloat(flakes) * 0.72
                let appear = min(max((encroach - delay) / 0.28, 0), 1)
                guard appear > 0.02 else { continue }

                let insetNoise = noiseValues[index].inset
                let inset = 4 + insetNoise * (6 + config.crackDensity * 10)
                let center = switch edge {
                case 0: CGPoint(x: along * size.width, y: inset)
                case 1: CGPoint(x: size.width - inset, y: along * size.height)
                case 2: CGPoint(x: along * size.width, y: size.height - inset)
                default: CGPoint(x: inset, y: along * size.height)
                }

                let twinkle: CGFloat = 0.72 + 0.28 * abs(sin(phase * .pi * 2.4 + insetNoise * .pi * 2))
                let breathe: CGFloat = 0.88 + 0.12 * twinkle
                let radiusVariance: CGFloat = 0.7 + insetNoise * 0.5
                let radius: CGFloat = radiusFraction * radiusVariance * appear * breathe * config.intensity
                let opacityBase: CGFloat = 0.3 + 0.55 * appear * config.frostOpacity
                let opacity = Double(opacityBase * twinkle)
                drawSnowflake(
                    in: &context,
                    at: center,
                    radius: radius,
                    rotation: along * .pi + insetNoise + phase * 0.15,
                    color: style.color.opacity(opacity * 0.7),
                    secondary: style.secondaryColor.opacity(opacity),
                )
            }
        }
    }
}

private func drawSnowflake(
    in context: inout GraphicsContext,
    at center: CGPoint,
    radius: CGFloat,
    rotation: CGFloat,
    color: Color,
    secondary: Color,
) {
    let path = StatusParticleGeometry.snowflake.applying(
        StatusParticleGeometry.transform(at: center, radius: radius, rotation: rotation),
    )
    context.fill(path, with: .color(color))
    context.stroke(path, with: .color(secondary), lineWidth: 0.8)
}

private enum StatusParticleGeometry {
    static let snowflake: Path = {
        var path = Path()
        for petal in 0 ..< 6 {
            let angle = CGFloat(petal) / 6 * .pi * 2
            let cosine = cos(angle)
            let sine = sin(angle)
            let tip = CGPoint(x: cosine, y: sine)
            let perp = CGVector(dx: -sine, dy: cosine)
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: tip.x + perp.dx * 0.28, y: tip.y + perp.dy * 0.28))
            path.addLine(to: tip)
            path.addLine(to: CGPoint(x: tip.x - perp.dx * 0.28, y: tip.y - perp.dy * 0.28))
            path.closeSubpath()
            let mid = CGPoint(x: cosine * 0.55, y: sine * 0.55)
            path.move(to: CGPoint(x: mid.x + perp.dx * 0.22, y: mid.y + perp.dy * 0.22))
            path.addLine(to: CGPoint(x: mid.x - perp.dx * 0.22, y: mid.y - perp.dy * 0.22))
        }
        return path
    }()

    static func transform(at center: CGPoint, radius: CGFloat, rotation: CGFloat) -> CGAffineTransform {
        let cosine = cos(rotation) * radius
        let sine = sin(rotation) * radius
        // Transform geometry, not the drawing context, so all stroke widths stay in points.
        return CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: center.x, ty: center.y)
    }
}

struct CombatantStatusCardTransform: ViewModifier {
    let kind: CombatantStatusEffectKind
    let config: CombatantStatusEffectConfig
    let progress: CGFloat

    func body(content: Content) -> some View {
        let phase = progress * config.speed
        let appear = kind == .swirlingStars
            ? min(max(phase / 0.12, 0), 1)
            : 0
        let wobble = appear > 0.01
            ? sin(phase * .pi * 2) * config.wobbleDegrees * config.intensity * appear
            : 0
        content.rotationEffect(.degrees(Double(wobble)))
    }
}

struct CombatantStatusEffectPresentation<Content: View>: View {
    @Environment(BattleSession.self) private var battleSession
    let keyword: Keyword?
    let content: Content

    @State private var startDate = Date()

    init(
        keyword: Keyword?,
        @ViewBuilder content: () -> Content,
    ) {
        self.keyword = keyword
        self.content = content()
    }

    var body: some View {
        if let keyword,
           let kind = CombatantStatusEffectKind(statusKeyword: keyword) {
            let config = CombatantStatusEffectConfig.defaults(for: kind)
            animatedOverlay(kind: kind, config: config)
        } else {
            content
        }
    }

    private func animatedOverlay(
        kind: CombatantStatusEffectKind,
        config: CombatantStatusEffectConfig,
    ) -> some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: battleSession.lifecyclePhase != .active
                    || battleSession.isSuspendedForScenePhase,
            ),
        ) { timeline in
            let progress = kind.progress(
                after: timeline.date.timeIntervalSince(startDate),
            )
            content
                .modifier(
                    CombatantStatusCardTransform(
                        kind: kind,
                        config: config,
                        progress: progress,
                    ),
                )
                .overlay {
                    CombatantStatusEffectOverlay(
                        kind: kind,
                        config: config,
                        progress: progress,
                    )
                }
        }
        .onChange(of: keyword) { _, _ in
            startDate = Date()
        }
        .onAppear {
            startDate = Date()
        }
    }
}

enum CombatantCardEffectNoise {
    static func value(_ index: Int, salt: Int) -> CGFloat {
        let n = sin(Double(index * 12989 + salt * 78433)) * 43758.5453
        return CGFloat(n - floor(n))
    }
}
