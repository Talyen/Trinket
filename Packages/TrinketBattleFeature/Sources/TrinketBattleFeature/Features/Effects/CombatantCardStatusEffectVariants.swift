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
            config.particleCount = 12
            config.frostOpacity = 0.82
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
        let radius = min(size.width, size.height) * config.orbitRadius * 0.5
        let appear = min(max(phase / 0.12, 0), 1)

        return Canvas { context, canvasSize in
            guard appear > 0.01 else { return }
            let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.28)
            let angleBase = phase * .pi * 2
            for index in 0 ..< count {
                let noise = CombatantCardEffectNoise.value(index, salt: 17)
                let angle = angleBase + CGFloat(index) / CGFloat(count) * .pi * 2
                    + noise * 0.35
                let radial = radius * (0.85 + noise * 0.3)
                let point = CGPoint(
                    x: center.x + cos(angle) * radial,
                    y: center.y + sin(angle) * radial,
                )
                let starSize = (4 + noise * 5) * config.intensity
                let twinkle = 0.45 + 0.55 * abs(sin(phase * .pi * 4 + noise * .pi * 2))
                let opacity = Double(twinkle * appear)
                drawStar(
                    in: &context,
                    at: point,
                    size: starSize,
                    color: style.color.opacity(opacity),
                    secondary: style.secondaryColor.opacity(opacity * 0.7),
                )
            }
        }
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
                    style.color.opacity(0.26 * veilOpacity),
                    lineWidth: 1.25,
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
        Canvas { context, _ in
            for index in 0 ..< flakes {
                let along = CombatantCardEffectNoise.value(index, salt: 41)
                let edge = index % 4
                let delay = CGFloat(index) / CGFloat(flakes) * 0.72
                let appear = min(max((encroach - delay) / 0.28, 0), 1)
                guard appear > 0.02 else { continue }

                let insetNoise = CombatantCardEffectNoise.value(index, salt: 47)
                let inset = 4 + insetNoise * (6 + config.crackDensity * 10)
                let center = switch edge {
                case 0: CGPoint(x: along * size.width, y: inset)
                case 1: CGPoint(x: size.width - inset, y: along * size.height)
                case 2: CGPoint(x: along * size.width, y: size.height - inset)
                default: CGPoint(x: inset, y: along * size.height)
                }

                let twinkle: CGFloat = 0.55 + 0.45 * abs(sin(phase * .pi * 2.4 + insetNoise * .pi * 2))
                let breathe: CGFloat = 0.88 + 0.12 * twinkle
                let radiusFraction: CGFloat = min(size.width, size.height)
                    * (0.01 + config.crackDensity * 0.018)
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

private func drawStar(
    in context: inout GraphicsContext,
    at point: CGPoint,
    size: CGFloat,
    color: Color,
    secondary: Color,
) {
    var path = Path()
    let spikes = 4
    for i in 0 ..< (spikes * 2) {
        let angle = CGFloat(i) * .pi / CGFloat(spikes) - .pi / 2
        let radius = i.isMultiple(of: 2) ? size : size * 0.38
        let p = CGPoint(
            x: point.x + cos(angle) * radius,
            y: point.y + sin(angle) * radius,
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

private func drawSnowflake(
    in context: inout GraphicsContext,
    at center: CGPoint,
    radius: CGFloat,
    rotation: CGFloat,
    color: Color,
    secondary: Color,
) {
    let petals = 6
    var path = Path()
    for petal in 0 ..< petals {
        let angle = CGFloat(petal) / CGFloat(petals) * .pi * 2 + rotation
        let tip = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius,
        )
        let side = radius * 0.28
        let perp = CGVector(dx: -sin(angle), dy: cos(angle))
        path.move(to: center)
        path.addLine(to: CGPoint(
            x: tip.x + perp.dx * side,
            y: tip.y + perp.dy * side,
        ))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(
            x: tip.x - perp.dx * side,
            y: tip.y - perp.dy * side,
        ))
        path.closeSubpath()

        let mid = CGPoint(
            x: center.x + cos(angle) * radius * 0.55,
            y: center.y + sin(angle) * radius * 0.55,
        )
        let arm = radius * 0.22
        path.move(to: CGPoint(x: mid.x + perp.dx * arm, y: mid.y + perp.dy * arm))
        path.addLine(to: CGPoint(x: mid.x - perp.dx * arm, y: mid.y - perp.dy * arm))
    }
    context.fill(path, with: .color(color))
    context.stroke(path, with: .color(secondary), lineWidth: 0.8)
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
            .animation(minimumInterval: 1.0 / 30.0, paused: battleSession.lifecyclePhase != .active),
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
