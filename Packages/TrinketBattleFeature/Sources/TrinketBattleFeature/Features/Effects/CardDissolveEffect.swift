import SwiftUI
import TrinketCore

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

struct CardDissolveConfiguration: Equatable {
    var dissolveDuration: CGFloat = 0.35
    var dissolveShrink: CGFloat = 0.06

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
}

struct CardActivationParticle: Equatable {
    let originXNoise: CGFloat
    let originYNoise: CGFloat
    let vector: CGVector
    let motionNoise: DissolveParticleNoise
    let curveNoise: CGFloat
    let colorNoise: CGFloat

    static let castParticles = make(count: BattleMotion.cardCastParticleCount)

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
    @State private var planCache = CardActivationParticlePlanCache()

    var body: some View {
        Canvas { context, size in
            let plan = planCache.plan(
                particles: particles, keywords: keywords, cardSize: cardSize, canvasSize: size, configuration: configuration,
            )
            for particle in plan {
                guard let motion = particle.motion.sample(progress: progress) else { continue }
                context.fillParticle(
                    center: particle.position(progress: motion.easedAge),
                    diameter: motion.diameter,
                    opacity: motion.opacity,
                    color: particle.color,
                )
            }
        }
        .allowsHitTesting(false)
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
                                CardDissolveThresholdMask(progress: dissolveProgress)
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

    @State private var startDate: Date? = CardDissolveTexture.isPrepared() ? .now : nil
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
            } else if let startDate {
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
                .task(id: startDate) {
                    try? await Task.sleep(for: .seconds(BattleMotion.cardActivationDuration))
                    guard !Task.isCancelled else { return }
                    isComplete = true
                    onFinished?()
                }
            } else {
                content
            }
        }
        .task {
            guard startDate == nil else { return }
            await CardDissolveTexture.prepare()
            guard !Task.isCancelled else { return }
            startDate = .now
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
