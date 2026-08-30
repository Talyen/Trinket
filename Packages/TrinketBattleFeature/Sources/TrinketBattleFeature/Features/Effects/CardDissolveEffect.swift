import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct DissolveParticleNoise: Equatable {
    let distance: CGFloat
    let delay: CGFloat
    let lifetime: CGFloat
    let size: CGFloat
    let fade: CGFloat
}

struct DissolveParticleSample {
    let distance: CGFloat
    let easedAge: CGFloat
    let diameter: CGFloat
    let opacity: Double
}

struct CardDissolveConfiguration {
    var dissolveDuration: CGFloat = 0.35
    var dissolveShrink: CGFloat = 0.06
    var dissolveEdgeDepthWeight: CGFloat = 0.86
    var dissolveNoiseWeight: CGFloat = 0.18
    var dissolveCellSize: CGFloat = 1
    var dissolveThresholdMidpoint: CGFloat = 0.46
    var dissolveThresholdContrast: CGFloat = 100

    var particleDistance: CGFloat = 150
    var particleDistanceVariation: CGFloat = 0
    var particleDelay: CGFloat = 0.10
    var particleLifetime: CGFloat = 0.55
    var particleLifetimeVariation: CGFloat = 0.15
    var particleCurve: CGFloat = 1.00
    var particleOriginSpread: CGFloat = 0.50
    var particleSize: CGFloat = 2.5
    var particleSizeVariation: CGFloat = 2.0
    var fadeStart: CGFloat = 0.20
    var fadeStartVariation: CGFloat = 0
    var particleAgeEasePower: CGFloat = 2.50
    var particleSizeShrink: CGFloat = 0.30
    var particleFadeExponent: CGFloat = 1.35
    var particlePathControl: CGFloat = 0.45

    func sample(progress: CGFloat, noise: DissolveParticleNoise) -> DissolveParticleSample {
        let distance = particleDistance + noise.distance * particleDistanceVariation
        let delay = noise.delay * particleDelay
        let lifetime = max(particleLifetime + noise.lifetime * particleLifetimeVariation, 0.01)
        let age = min(max((progress - delay) / lifetime, 0), 1)
        let easedAge = 1 - pow(1 - age, max(particleAgeEasePower, 0.01))
        let diameter = max(
            0,
            (particleSize + noise.size * particleSizeVariation)
                * (1 - age * particleSizeShrink),
        )
        let resolvedFadeStart = min(max(fadeStart + noise.fade * fadeStartVariation, 0), 0.99)
        let fadeProgress = max(0, (age - resolvedFadeStart) / (1 - resolvedFadeStart))
        let opacity = progress >= delay && age < 1
            ? Double(pow(1 - fadeProgress, max(particleFadeExponent, 0.01)))
            : 0
        return DissolveParticleSample(
            distance: distance,
            easedAge: easedAge,
            diameter: diameter,
            opacity: opacity,
        )
    }
}

struct CardActivationParticle: Equatable {
    let originXNoise: CGFloat
    let originYNoise: CGFloat
    let vector: CGVector
    let motionNoise: DissolveParticleNoise
    let curveNoise: CGFloat
    let colorNoise: CGFloat

    static func make(count: Int) -> [Self] {
        (0 ..< max(0, count)).map { index in
            let angle = dissolveNoise(column: index, row: 41) * 2 * .pi
            return Self(
                originXNoise: dissolveNoise(column: index, row: 13),
                originYNoise: dissolveNoise(column: index, row: 29),
                vector: CGVector(dx: cos(angle), dy: sin(angle)),
                motionNoise: DissolveParticleNoise(
                    distance: dissolveNoise(column: index, row: 53),
                    delay: dissolveNoise(column: index, row: 61),
                    lifetime: dissolveNoise(column: index, row: 67),
                    size: dissolveNoise(column: index, row: 79),
                    fade: dissolveNoise(column: index, row: 101),
                ),
                curveNoise: dissolveNoise(column: index, row: 83),
                colorNoise: dissolveNoise(column: index, row: 109),
            )
        }
    }
}

struct CardActivationParticles: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let cardSize: CGSize
    let particles: [CardActivationParticle]
    var configuration = CardDissolveConfiguration()

    var body: some View {
        Canvas { context, size in
            guard !keywords.isEmpty else { return }
            for particle in particles {
                let sample = sample(for: particle, size: size)
                guard sample.opacity > 0, sample.diameter > 0 else { continue }
                let rect = CGRect(
                    x: sample.center.x - sample.diameter / 2,
                    y: sample.center.y - sample.diameter / 2,
                    width: sample.diameter,
                    height: sample.diameter,
                )
                var particleContext = context
                particleContext.opacity = sample.opacity
                particleContext.fill(
                    Path(ellipseIn: rect),
                    with: .color(keywordColor(for: particle)),
                )
            }
        }
        .allowsHitTesting(false)
    }

    private struct Sample {
        let center: CGPoint
        let diameter: CGFloat
        let opacity: Double
    }

    private func sample(for particle: CardActivationParticle, size: CGSize) -> Sample {
        let motion = configuration.sample(progress: progress, noise: particle.motionNoise)
        let curve = (particle.curveNoise - 0.5) * motion.distance * configuration.particleCurve
        let center = curvedPosition(
            from: particleOrigin(particle, size: size),
            vector: particle.vector,
            distance: motion.distance,
            curve: curve,
            progress: motion.easedAge,
        )
        return Sample(center: center, diameter: motion.diameter, opacity: motion.opacity)
    }

    private func keywordColor(for particle: CardActivationParticle) -> Color {
        let index = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
        return keywords[index].visualStyle.color
    }

    private func particleOrigin(_ particle: CardActivationParticle, size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (particle.originXNoise - 0.5)
                * cardSize.width * configuration.particleOriginSpread,
            y: size.height / 2 + (particle.originYNoise - 0.5)
                * cardSize.height * configuration.particleOriginSpread,
        )
    }

    private func curvedPosition(
        from origin: CGPoint,
        vector: CGVector,
        distance: CGFloat,
        curve: CGFloat,
        progress: CGFloat,
    ) -> CGPoint {
        let perpendicular = CGVector(dx: -vector.dy, dy: vector.dx)
        let pathControl = min(max(configuration.particlePathControl, 0), 1)
        let end = CGPoint(
            x: origin.x + vector.dx * distance,
            y: origin.y + vector.dy * distance,
        )
        let control = CGPoint(
            x: origin.x + vector.dx * distance * pathControl + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * pathControl + perpendicular.dy * curve,
        )
        let remaining = 1 - progress
        return CGPoint(
            x: remaining * remaining * origin.x
                + 2 * remaining * progress * control.x
                + progress * progress * end.x,
            y: remaining * remaining * origin.y
                + 2 * remaining * progress * control.y
                + progress * progress * end.y,
        )
    }
}

struct CardDissolveEffect<Content: View>: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let size: CGSize
    let particles: [CardActivationParticle]
    let content: Content
    var configuration = CardDissolveConfiguration()

    init(
        progress: CGFloat,
        keywords: [Keyword],
        size: CGSize,
        particles: [CardActivationParticle],
        configuration: CardDissolveConfiguration = CardDissolveConfiguration(),
        @ViewBuilder content: () -> Content,
    ) {
        self.progress = progress
        self.keywords = keywords
        self.size = size
        self.particles = particles
        self.configuration = configuration
        self.content = content()
    }

    var body: some View {
        let dissolveProgress = min(progress / max(configuration.dissolveDuration, 0.01), 1)
        let cellSize = Int(configuration.dissolveCellSize.rounded())

        ZStack {
            if dissolveProgress < 1 {
                Group {
                    if dissolveProgress <= 0 {
                        content
                            .frame(width: size.width, height: size.height)
                    } else {
                        content
                            .frame(width: size.width, height: size.height)
                            .mask {
                                CardDissolveThresholdMask(
                                    progress: dissolveProgress,
                                    edgeDepthWeight: configuration.dissolveEdgeDepthWeight,
                                    noiseWeight: configuration.dissolveNoiseWeight,
                                    cellSize: cellSize,
                                    thresholdMidpoint: configuration.dissolveThresholdMidpoint,
                                    thresholdContrast: configuration.dissolveThresholdContrast,
                                )
                            }
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(1 - dissolveProgress * configuration.dissolveShrink)
                .compositingGroup()
            }

            if !particles.isEmpty {
                let travelPad = configuration.particleDistance
                    + configuration.particleDistanceVariation
                    + 40
                CardActivationParticles(
                    progress: progress,
                    keywords: keywords,
                    cardSize: size,
                    particles: particles,
                    configuration: configuration,
                )
                .frame(width: size.width + travelPad * 2, height: size.height + travelPad * 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private enum CardDissolveParticles {
    static let standard = CardActivationParticle.make(count: 20)
}

public struct CardDissolveArtwork<Content: View>: View {
    let onFinished: (() -> Void)?
    let content: Content

    @State private var startDate = Date()
    @State private var isComplete = false
    private let particles = CardDissolveParticles.standard
    private let keywords: [Keyword] = [.physical]
    private let configuration = CardDissolveConfiguration()

    public init(
        onFinished: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
    ) {
        self.onFinished = onFinished
        self.content = content()
    }

    public var body: some View {
        Group {
            if isComplete {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    GeometryReader { geometry in
                        let progress = cardActivationProgress(
                            elapsed: timeline.date.timeIntervalSince(startDate),
                        )

                        CardDissolveEffect(
                            progress: progress,
                            keywords: keywords,
                            size: geometry.size,
                            particles: particles,
                            configuration: configuration,
                        ) {
                            content
                        }
                    }
                }
                .onAppear {
                    startDate = Date()
                    isComplete = false
                }
                .task(id: startDate) {
                    try? await Task.sleep(for: .seconds(BattleMotion.cardActivationDuration))
                    guard !Task.isCancelled else { return }
                    isComplete = true
                    onFinished?()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

func cardActivationProgress(elapsed: TimeInterval) -> CGFloat {
    CGFloat(min(max(elapsed / BattleMotion.cardActivationDuration, 0), 1))
}

private func dissolveNoise(column: Int, row: Int) -> CGFloat {
    CombatFeedbackLayout.unitNoise(seed: column &* 12989 &+ row &* 78233)
}
