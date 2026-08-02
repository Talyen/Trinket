import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
// DEBUG playground only — production motion lives in recipe/config types. Do not ship lab UI.

enum CombatantDeathEffectKind: String, CaseIterable, Identifiable {
    case verticalSplit
    case shatter
    case peelAway
    case dissolveBaseline

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .verticalSplit: "Vertical Split"
        case .shatter: "Shatter"
        case .peelAway: "Peel Away"
        case .dissolveBaseline: "Dissolve Baseline"
        }
    }
}

struct CombatantDeathEffectConfig: Equatable {
    var intensity: CGFloat = 1
    var particleCount: Int = 24
    var tintStrength: CGFloat = 0.2
    var speed: CGFloat = 1

    /// Horizontal gap between split halves as a fraction of card width.
    var splitGap: CGFloat = 0.22
    /// Hold before split halves begin to separate (0…1 of the clip).
    var splitDelay: CGFloat = 0.18
    /// Downward drift reserved for other variants; split uses sideways motion only.
    var gravity: CGFloat = 0.2
    /// Outward shard travel as a fraction of card min dimension.
    var shardTravel: CGFloat = 0.55
    /// Celebrate dissolve with gold/holy fireworks (Dissolve Baseline).
    var celebrateDissolve = true

    static func defaults(for kind: CombatantDeathEffectKind) -> Self {
        var config = Self()
        switch kind {
        case .verticalSplit:
            config.splitGap = 0.22
            config.splitDelay = 0.2
            config.particleCount = 0
        case .shatter:
            config.particleCount = 36
            config.shardTravel = 0.22
            config.gravity = 0.15
        case .peelAway:
            config.particleCount = 0
            config.splitGap = 0.35
        case .dissolveBaseline:
            config.celebrateDissolve = true
            config.particleCount = 28
        }
        return config
    }
}

struct CombatantDeathEffect<Content: View>: View {
    let kind: CombatantDeathEffectKind
    let config: CombatantDeathEffectConfig
    let progress: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            switch kind {
            case .verticalSplit:
                verticalSplit(size: size)
            case .shatter:
                shatter(size: size)
            case .peelAway:
                peelAway(size: size)
            case .dissolveBaseline:
                dissolveBaseline(size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private var effectiveProgress: CGFloat {
        min(max(progress * config.speed, 0), 1)
    }

    private var eased: CGFloat {
        let t = effectiveProgress
        return 1 - pow(1 - t, 2.2)
    }

    private func verticalSplit(size: CGSize) -> some View {
        let delay = min(max(config.splitDelay, 0), 0.6)
        let p = effectiveProgress
        let splitT = delay >= 1 ? 0 : min(max((p - delay) / (1 - delay), 0), 1)
        let splitEased = 1 - pow(1 - splitT, 2.0)
        let gap = size.width * config.splitGap * splitEased * config.intensity
        let lift = size.height * 0.06 * splitEased * config.intensity
        let twist = 6.0 * Double(splitEased * config.intensity)
        // Hold full opacity until late in the split, then fade out.
        let fade = Double(splitEased < 0.72 ? 1 : 1 - (splitEased - 0.72) / 0.28)
        let crackFlash = p < delay + 0.12
            ? Double((1 - abs(p - delay) / 0.12).clamped(to: 0 ... 1)) * Double(config.tintStrength)
            : 0

        return ZStack {
            // Hold the intact card until the split delay elapses.
            if splitT <= 0 {
                content()
                    .frame(width: size.width, height: size.height)
                    .clipShape(TrinketDesign.cardShape)
            } else {
                halfCard(size: size, isLeft: true)
                    .offset(x: -gap / 2, y: -lift)
                    .rotationEffect(.degrees(-twist), anchor: .trailing)
                    .opacity(fade)

                halfCard(size: size, isLeft: false)
                    .offset(x: gap / 2, y: lift)
                    .rotationEffect(.degrees(twist), anchor: .leading)
                    .opacity(fade)
            }

            if crackFlash > 0 {
                Rectangle()
                    .fill(Keyword.physical.visualStyle.color.opacity(crackFlash))
                    .frame(width: 2 + 3 * CGFloat(crackFlash), height: size.height)
                    .blur(radius: 0.8)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func halfCard(size: CGSize, isLeft: Bool) -> some View {
        content()
            .frame(width: size.width, height: size.height)
            .clipShape(TrinketDesign.cardShape)
            .mask(
                HStack(spacing: 0) {
                    if isLeft {
                        Rectangle()
                        Color.clear
                    } else {
                        Color.clear
                        Rectangle()
                    }
                }
            )
    }

    /// Shatters the portrait into small irregular shards of the artwork.
    private func shatter(size: CGSize) -> some View {
        let t = eased
        let shards = DeathCardShard.make(count: max(config.particleCount, 20))
        let travel = min(size.width, size.height) * config.shardTravel * config.intensity

        return ZStack {
            ForEach(shards) { shard in
                let age = min(max((t - shard.delay) / max(1 - shard.delay, 0.01), 0), 1)
                let fly = 1 - pow(1 - age, 1.55)
                // Full opacity until late; fade only near the end.
                let fade = Double(age < 0.7 ? 1 : 1 - (age - 0.7) / 0.3)
                content()
                    .frame(width: size.width, height: size.height)
                    .clipShape(TrinketDesign.cardShape)
                    .mask(
                        ShardMask(shard: shard)
                            .frame(width: size.width, height: size.height)
                    )
                    .offset(
                        x: cos(shard.angle) * travel * fly,
                        y: sin(shard.angle) * travel * fly
                            + size.height * config.gravity * 0.45 * fly * fly
                    )
                    .rotationEffect(.degrees(Double(shard.spin * fly * 28 * config.intensity)))
                    .opacity(fade)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Sticker-like peel from the top-trailing corner, curling off the frame.
    private func peelAway(size: CGSize) -> some View {
        let t = eased
        let peel = min(max(t / 0.85, 0), 1)
        let curl = peel * 55 * config.intensity
        let slide = size.width * config.splitGap * peel * config.intensity

        return ZStack {
            // Remaining card under a diagonal wipe that grows with peel.
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(TrinketDesign.cardShape)
                .mask(
                    PeelRemainMask(progress: peel)
                        .frame(width: size.width, height: size.height)
                )
                .opacity(Double(1 - peel * 0.15))

            // Peeled flap: same art, masked to the peeled region, curling away.
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(TrinketDesign.cardShape)
                .mask(
                    PeelFlapMask(progress: peel)
                        .frame(width: size.width, height: size.height)
                )
                .rotation3DEffect(
                    .degrees(Double(curl)),
                    axis: (x: 0.15, y: 1, z: 0.05),
                    anchor: .topTrailing,
                    perspective: 0.55
                )
                .offset(x: slide, y: -slide * 0.25)
                .opacity(Double(1 - peel * 0.85))
        }
        .frame(width: size.width, height: size.height)
    }

    private func dissolveBaseline(size: CGSize) -> some View {
        let particles = CardActivationParticle.make(
            count: config.particleCount,
            spread: config.celebrateDissolve ? .fireworks : .radial
        )
        let keywords: [Keyword] = config.celebrateDissolve ? [.gold, .holy] : [.physical]
        let configuration: CardCastEffectConfiguration = config.celebrateDissolve
            ? .defeatCelebration
            : CardCastEffectConfiguration()

        return BattleDissolveEffect(
            progress: effectiveProgress,
            keywords: keywords,
            size: size,
            particles: particles,
            configuration: configuration
        ) {
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(TrinketDesign.cardShape)
        }
    }
}

private struct DeathCardShard: Identifiable {
    let id: Int
    let polygon: [CGPoint]
    let angle: CGFloat
    let spin: CGFloat
    let delay: CGFloat

    /// Dense pack of small irregular shard polygons (triangles / splinters), not grid squares.
    static func make(count: Int) -> [Self] {
        let columns = max(Int(ceil(sqrt(Double(count) * 1.15))), 4)
        let rows = max(Int(ceil(Double(count) / Double(columns))), 4)
        var shards: [Self] = []
        var id = 0
        for row in 0 ..< rows {
            for column in 0 ..< columns {
                guard id < count else { break }
                let cellW = 1 / CGFloat(columns)
                let cellH = 1 / CGFloat(rows)
                let cx = (CGFloat(column) + 0.5) * cellW
                let cy = (CGFloat(row) + 0.5) * cellH
                let rotation = CombatantCardEffectNoise.value(id, salt: 97) * .pi * 2
                let elongation = 0.7 + CombatantCardEffectNoise.value(id, salt: 101) * 1.1
                // Keep shards smaller than the cell so shapes read as splinters, not tiles.
                let scale = min(cellW, cellH) * (0.42 + CombatantCardEffectNoise.value(id, salt: 95) * 0.28)
                let sides = 3 + id % 3
                var polygon: [CGPoint] = []
                for vertex in 0 ..< sides {
                    let base = CGFloat(vertex) / CGFloat(sides) * .pi * 2 + rotation
                    let radiusJitter = 0.5 + CombatantCardEffectNoise.value(id * 10 + vertex, salt: 103) * 0.75
                    let rx = cos(base) * scale * radiusJitter * elongation
                    let ry = sin(base) * scale * radiusJitter / max(elongation * 0.7, 0.45)
                    // Slight cell-local jitter so shards don't align on a grid.
                    let jx = (CombatantCardEffectNoise.value(id, salt: 111) - 0.5) * cellW * 0.2
                    let jy = (CombatantCardEffectNoise.value(id, salt: 113) - 0.5) * cellH * 0.2
                    polygon.append(CGPoint(
                        x: (cx + jx + rx).clamped(to: 0.005 ... 0.995),
                        y: (cy + jy + ry).clamped(to: 0.005 ... 0.995)
                    ))
                }
                shards.append(
                    Self(
                        id: id,
                        polygon: polygon,
                        angle: atan2(cy - 0.5, cx - 0.5)
                            + (CombatantCardEffectNoise.value(id, salt: 105) - 0.5) * 0.8,
                        spin: (CombatantCardEffectNoise.value(id, salt: 107) - 0.5) * 2,
                        delay: CombatantCardEffectNoise.value(id, salt: 109) * 0.1
                    )
                )
                id += 1
            }
        }
        return shards
    }
}

private struct ShardMask: Shape {
    let shard: DeathCardShard

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = shard.polygon.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct PeelRemainMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Keep everything below the diagonal that advances from top-trailing.
        let cut = progress
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PeelFlapMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cut = max(progress, 0.001)
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - rect.width * cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * cut))
        path.closeSubpath()
        return path
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
