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
    case iceCrystals

    var id: Self {
        self
    }

    var category: CombatantCardEffectCategory {
        switch self {
        case .swirlingStars:
            .stunned
        case .iceCrystals:
            .frozen
        }
    }

    var title: String {
        switch self {
        case .swirlingStars: "Swirling Stars"
        case .iceCrystals: "Ice Crystals"
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
    /// Card wobble amplitude in degrees (Swirling Stars).
    var wobbleDegrees: CGFloat = 2.4
    /// Frost opacity (Ice Crystals).
    var frostOpacity: CGFloat = 0.45
    /// Edge frost density 0…1 (Ice Crystals).
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
            config.particleCount = 40
            config.frostOpacity = 0.75
            config.crackDensity = 0.7
            config.tintStrength = 0
        }
        return config
    }
}

/// Lab playback length defaults per variant.
enum CombatantCardEffectLabDuration {
    static func defaults(
        category: CombatantCardEffectCategory,
        deathKind: CombatantDeathEffectKind = .slice
    ) -> CGFloat {
        switch category {
        case .stunned:
            4.0
        case .frozen:
            4.0
        case .death:
            switch deathKind {
            case .slice: 2.5
            case .dissolveBaseline: 1.4
            }
        }
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
        // Fade in once from absolute phase 0 (replay / scrub start) — never remaps per loop,
        // so orbit + twinkle stay continuous across cycle wraps.
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
                    y: center.y + sin(angle) * radial
                )
                let starSize = (4 + noise * 5) * config.intensity
                let twinkle = 0.45 + 0.55 * abs(sin(phase * .pi * 4 + noise * .pi * 2))
                let opacity = Double(twinkle * appear)
                drawStar(
                    in: &context,
                    at: point,
                    size: starSize,
                    color: style.color.opacity(opacity),
                    secondary: style.secondaryColor.opacity(opacity * 0.7)
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// Edge snowflakes plus a faint frosty veil that creeps inward from the rim.
    /// Inward encroachment caps once, then flakes keep twinkling and the veil pulses.
    private func iceCrystals(size: CGSize, style: Keyword.VisualStyle, phase: CGFloat) -> some View {
        let flakes = max(config.particleCount, 12)
        // First ~35% of absolute phase grows frost inward; then coverage stays maxed.
        let encroach = min(max(phase / 0.35, 0), 1)
        let minDim = min(size.width, size.height)
        // Clear center shrinks as frost encroaches from the edges.
        let clearRadius = minDim * 0.55 * (1 - encroach * (0.55 + config.crackDensity * 0.3))
        let edgeRadius = minDim * 0.78
        // Subtle ongoing pulse after the rim is fully frosted.
        let pulse = encroach >= 1
            ? 0.88 + 0.12 * (0.5 + 0.5 * sin(phase * .pi * 2))
            : 1
        let veilOpacity = Double(encroach * config.frostOpacity * config.intensity * pulse)

        return ZStack {
            RadialGradient(
                colors: [
                    Color.clear,
                    style.glowColor.opacity(0.06 * veilOpacity),
                    style.color.opacity(0.18 * veilOpacity),
                    style.secondaryColor.opacity(0.32 * veilOpacity),
                ],
                center: .center,
                startRadius: max(clearRadius, 0),
                endRadius: max(edgeRadius, clearRadius + 1)
            )

            Canvas { context, _ in
                for index in 0 ..< flakes {
                    let along = CombatantCardEffectNoise.value(index, salt: 41)
                    let edge = index % 4
                    // Stagger so flakes densify around the rim as encroachment plays.
                    let delay = CGFloat(index) / CGFloat(flakes) * 0.72
                    let appear = min(max((encroach - delay) / 0.28, 0), 1)
                    guard appear > 0.02 else { continue }

                    let insetNoise = CombatantCardEffectNoise.value(index, salt: 47)
                    // Stay near the rim; denser density pushes slightly further inward.
                    let inset = 4 + insetNoise * (6 + config.crackDensity * 10)
                    let center = switch edge {
                    case 0: CGPoint(x: along * size.width, y: inset)
                    case 1: CGPoint(x: size.width - inset, y: along * size.height)
                    case 2: CGPoint(x: along * size.width, y: size.height - inset)
                    default: CGPoint(x: inset, y: along * size.height)
                    }

                    // Keep twinkling after fully revealed.
                    let twinkle = 0.55 + 0.45 * abs(sin(phase * .pi * 2.4 + insetNoise * .pi * 2))
                    let breathe = 0.88 + 0.12 * twinkle
                    let radius = minDim
                        * (0.01 + config.crackDensity * 0.018)
                        * (0.7 + insetNoise * 0.5)
                        * appear
                        * breathe
                        * config.intensity
                    let opacity = Double(
                        (0.3 + 0.55 * appear * config.frostOpacity) * twinkle
                    )
                    drawSnowflake(
                        in: &context,
                        at: center,
                        radius: radius,
                        rotation: along * .pi + insetNoise + phase * 0.15,
                        color: style.color.opacity(opacity * 0.7),
                        secondary: style.secondaryColor.opacity(opacity)
                    )
                }
            }
        }
        .clipShape(TrinketDesign.cardShape)
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

/// Compact multi-petal snowflake (same family as the former Rime Bloom petals).
private func drawSnowflake(
    in context: inout GraphicsContext,
    at center: CGPoint,
    radius: CGFloat,
    rotation: CGFloat,
    color: Color,
    secondary: Color
) {
    let petals = 6
    var path = Path()
    for petal in 0 ..< petals {
        let angle = CGFloat(petal) / CGFloat(petals) * .pi * 2 + rotation
        let tip = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
        let side = radius * 0.28
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

        // Short cross-arm for a more snowflake-like silhouette.
        let mid = CGPoint(
            x: center.x + cos(angle) * radius * 0.55,
            y: center.y + sin(angle) * radius * 0.55
        )
        let arm = radius * 0.22
        path.move(to: CGPoint(x: mid.x + perp.dx * arm, y: mid.y + perp.dy * arm))
        path.addLine(to: CGPoint(x: mid.x - perp.dx * arm, y: mid.y - perp.dy * arm))
    }
    context.fill(path, with: .color(color))
    context.stroke(path, with: .color(secondary), lineWidth: 0.65)
}

/// Card wobble for Swirling Stars (gated so rest looks normal).
struct CombatantStatusCardTransform: ViewModifier {
    let kind: CombatantStatusEffectKind
    let config: CombatantStatusEffectConfig
    let progress: CGFloat

    func body(content: Content) -> some View {
        let phase = progress * config.speed
        // Absolute phase — no per-loop remapping, so wobble stays continuous.
        let appear = kind == .swirlingStars
            ? min(max(phase / 0.12, 0), 1)
            : 0
        let wobble = appear > 0.01
            ? sin(phase * .pi * 2) * config.wobbleDegrees * config.intensity * appear
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
