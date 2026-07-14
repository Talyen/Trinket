import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CardActivationRequest: Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let artworkName: String?
    let center: CGPoint
    let size: CGSize
    let rotation: CGFloat
    let verticalTilt: CGFloat
    let scale: CGFloat
    let keywords: [Keyword]
    let particleCount: Int
    let particles: [CardActivationParticle]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        artworkName: String?,
        center: CGPoint,
        size: CGSize,
        rotation: CGFloat,
        verticalTilt: CGFloat,
        scale: CGFloat,
        keywords: [Keyword],
        particleCount: Int = 50
    ) {
        self.id = id
        self.startedAt = startedAt
        self.artworkName = artworkName
        self.center = center
        self.size = size
        self.rotation = rotation
        self.verticalTilt = verticalTilt
        self.scale = scale
        let uniqueKeywords = keywords.reduce(into: [Keyword]()) { result, keyword in
            guard !result.contains(keyword) else { return }
            result.append(keyword)
        }
        self.keywords = uniqueKeywords.isEmpty ? [.physical] : uniqueKeywords
        self.particleCount = particleCount
        particles = CardActivationParticle.make(count: particleCount)
    }
}

struct CardActivationParticle: Equatable {
    let originXNoise: CGFloat
    let originYNoise: CGFloat
    let vector: CGVector
    let distanceNoise: CGFloat
    let delayNoise: CGFloat
    let lifetimeNoise: CGFloat
    let curveNoise: CGFloat
    let sizeNoise: CGFloat
    let fadeNoise: CGFloat
    let colorNoise: CGFloat

    static func make(count: Int) -> [Self] {
        (0 ..< max(0, count)).map { index in
            let angle = dissolveNoise(column: index, row: 41) * 2 * .pi
            return Self(
                originXNoise: dissolveNoise(column: index, row: 13),
                originYNoise: dissolveNoise(column: index, row: 29),
                vector: CGVector(dx: cos(angle), dy: sin(angle)),
                distanceNoise: dissolveNoise(column: index, row: 53),
                delayNoise: dissolveNoise(column: index, row: 61),
                lifetimeNoise: dissolveNoise(column: index, row: 67),
                curveNoise: dissolveNoise(column: index, row: 83),
                sizeNoise: dissolveNoise(column: index, row: 79),
                fadeNoise: dissolveNoise(column: index, row: 101),
                colorNoise: dissolveNoise(column: index, row: 109)
            )
        }
    }
}

/// All active casts share one display-linked clock. Per-request cleanup remains
/// independently cancellable when a cast disappears early.
struct CardCastEffectsLayer: View {
    let requests: [CardActivationRequest]
    let onFinished: (UUID) -> Void

    var body: some View {
        Group {
            if !requests.isEmpty {
                ZStack {
                    TimelineView(.animation) { timeline in
                        ZStack {
                            ForEach(requests) { request in
                                cast(request, at: timeline.date)
                            }
                        }
                    }

                    ForEach(requests) { request in
                        Color.clear
                            .frame(width: 0, height: 0)
                            .task(id: request.id) {
                                let elapsed = Date.now.timeIntervalSince(request.startedAt)
                                let remaining = max(0, TrinketMotion.Battle.cardActivationDuration - elapsed)
                                try? await Task.sleep(for: .seconds(remaining))
                                guard !Task.isCancelled else { return }
                                onFinished(request.id)
                            }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cast(_ request: CardActivationRequest, at date: Date) -> some View {
        let progress = cardActivationProgress(elapsed: date.timeIntervalSince(request.startedAt))
        return BattleDissolveEffect(
            progress: progress,
            keywords: request.keywords,
            size: request.size,
            particles: request.particles
        ) {
            BattleAbilityCardFace(artworkName: request.artworkName)
        }
        .rotationEffect(.radians(request.rotation), anchor: .bottom)
        .rotation3DEffect(
            .degrees(request.verticalTilt),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.35
        )
        .scaleEffect(request.scale)
        .position(x: request.center.x, y: request.center.y)
    }
}

struct CardCastEffectConfiguration {
    var dissolveDuration: CGFloat = 0.50
    var dissolveEdgeWidth: CGFloat = 0.02
    var dissolveCellScale: CGFloat = 0.20
    var particleDistance: CGFloat = 220
    var particleDistanceVariation: CGFloat = 0
    var particleDelay: CGFloat = 0.40
    var particleLifetime: CGFloat = 0.70
    var particleLifetimeVariation: CGFloat = 0.20
    var particleCurve: CGFloat = 1.75
    var particleOriginSpread: CGFloat = 0.60
    var particleSize: CGFloat = 4.0
    var particleSizeVariation: CGFloat = 3.0
    var fadeStart: CGFloat = 0.30
    var fadeStartVariation: CGFloat = 0
}

struct BattleDissolveEffect<Content: View>: View {
    let progress: CGFloat
    let keywords: [Keyword]
    let size: CGSize
    let particles: [CardActivationParticle]
    let content: Content
    var configuration = CardCastEffectConfiguration()

    init(
        progress: CGFloat,
        keywords: [Keyword],
        size: CGSize,
        particles: [CardActivationParticle],
        configuration: CardCastEffectConfiguration = CardCastEffectConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.keywords = keywords
        self.size = size
        self.particles = particles
        self.configuration = configuration
        self.content = content()
    }

    var body: some View {
        let dissolveProgress = min(progress / configuration.dissolveDuration, 1)
        ZStack {
            content
                .frame(width: size.width, height: size.height)
                .mask {
                    CardDissolveThresholdMask(progress: dissolveProgress)
                }

            LinearGradient(
                colors: keywords.map(\.visualStyle.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask {
                CardDissolveEdgeMask(
                    progress: dissolveProgress,
                    edgeWidth: configuration.dissolveEdgeWidth,
                    cellScale: configuration.dissolveCellScale
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(1 - dissolveProgress * 0.06)
        .overlay {
            CardActivationParticles(
                progress: progress,
                keywords: keywords,
                cardSize: size,
                particles: particles,
                configuration: configuration
            )
            .frame(width: size.width + 360, height: size.height + 360)
        }
    }
}

struct BattleDissolveArtwork<Content: View>: View {
    let content: Content

    @State private var startDate = Date()
    private let particles = CardActivationParticle.make(count: 50)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let progress = cardActivationProgress(
                    elapsed: timeline.date.timeIntervalSince(startDate)
                )

                BattleDissolveEffect(
                    progress: progress,
                    keywords: [.physical],
                    size: geometry.size,
                    particles: particles
                ) {
                    content
                }
            }
        }
        .onAppear {
            startDate = Date()
        }
        .allowsHitTesting(false)
    }
}

/// Primes the dissolve texture filters and particle Canvas before the first activation.
struct CardCastEffectsPrewarmView: View {
    private let cardSize = CGSize(width: 168, height: 224)
    private let particles = CardActivationParticle.make(count: 12)

    var body: some View {
        BattleDissolveEffect(
            progress: 0.45,
            keywords: [.physical],
            size: cardSize,
            particles: particles
        ) {
            Rectangle().fill(TrinketDesign.Colors.Overlay.paper)
        }
        // A nonzero opacity ensures the render is not optimized away. Scaling
        // happens after Canvas rasterization, so the representative workload is
        // still prepared while remaining visually imperceptible.
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
    }
}

private struct CardActivationParticles: View {
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
                let easedAge = 1 - pow(1 - age, 2)
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
                    * (1 - age * 0.38)
                let rect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                let fadeStart = configuration.fadeStart
                    + particle.fadeNoise * configuration.fadeStartVariation
                let fadeProgress = max(0, (age - fadeStart) / (1 - fadeStart))
                context.opacity = pow(1 - fadeProgress, 1.35)
                let colorIndex = min(Int(particle.colorNoise * CGFloat(keywords.count)), keywords.count - 1)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(keywords[colorIndex].visualStyle.color)
                )
            }
        }
        .allowsHitTesting(false)
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
        let end = CGPoint(
            x: origin.x + vector.dx * distance,
            y: origin.y + vector.dy * distance
        )
        let control = CGPoint(
            x: origin.x + vector.dx * distance * 0.45 + perpendicular.dx * curve,
            y: origin.y + vector.dy * distance * 0.45 + perpendicular.dy * curve
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

private func dissolveNoise(column: Int, row: Int) -> CGFloat {
    CombatFeedbackLayout.unitNoise(seed: column &* 12989 &+ row &* 78233)
}

private func cardActivationProgress(elapsed: TimeInterval) -> CGFloat {
    CGFloat(min(max(elapsed / TrinketMotion.Battle.cardActivationDuration, 0), 1))
}

#if DEBUG
private struct CardCastEffectPlayground: View {
    private let cardSize = CGSize(width: 168, height: 224)

    @State private var configuration = CardCastEffectConfiguration()
    @State private var particleCount = 50
    @State private var duration: CGFloat = 1.0
    @State private var scrubProgress: CGFloat = 0.18
    @State private var playsAutomatically = true
    @State private var playbackStart = Date()
    @State private var keyword = Keyword.burn

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.animation) { timeline in
                BattleDissolveEffect(
                    progress: progress(at: timeline.date),
                    keywords: [keyword, .physical],
                    size: cardSize,
                    particles: CardActivationParticle.make(count: particleCount),
                    configuration: configuration
                ) {
                    BattleAbilityCardFace(artworkName: nil)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .trinketSurface(.base)

            Form {
                Section("Playback") {
                    Toggle("Auto-play", isOn: $playsAutomatically)
                        .onChange(of: playsAutomatically) { _, isPlaying in
                            if isPlaying {
                                playbackStart = Date()
                            }
                        }
                    parameterSlider("Duration", value: $duration, range: 0.4 ... 2.5, format: "%.2f s")
                    parameterSlider("Progress", value: $scrubProgress, range: 0 ... 1, format: "%.2f")
                        .disabled(playsAutomatically)
                    Button("Replay") {
                        playbackStart = Date()
                        playsAutomatically = true
                    }
                }

                Section("Particles") {
                    Stepper("Count: \(particleCount)", value: $particleCount, in: 0 ... 400, step: 10)
                    Picker("Palette", selection: $keyword) {
                        ForEach(Keyword.allCases) { keyword in
                            Text(keyword.rawValue).tag(keyword)
                        }
                    }
                    parameterSlider("Travel", value: $configuration.particleDistance, range: 20 ... 220, format: "%.0f pt")
                    parameterSlider("Variation", value: $configuration.particleDistanceVariation, range: 0 ... 240, format: "%.0f pt")
                    parameterSlider("Curve", value: $configuration.particleCurve, range: 0 ... 2.5, format: "%.2f")
                    parameterSlider("Origin spread", value: $configuration.particleOriginSpread, range: 0 ... 1, format: "%.2f")
                    parameterSlider("Base size", value: $configuration.particleSize, range: 0.5 ... 8, format: "%.1f pt")
                    parameterSlider("Size variation", value: $configuration.particleSizeVariation, range: 0 ... 12, format: "%.1f pt")
                    parameterSlider("Max delay", value: $configuration.particleDelay, range: 0 ... 0.6, format: "%.2f")
                    parameterSlider("Lifetime", value: $configuration.particleLifetime, range: 0.2 ... 1, format: "%.2f")
                    parameterSlider("Lifetime variation", value: $configuration.particleLifetimeVariation, range: 0 ... 0.6, format: "%.2f")
                    parameterSlider("Fade start", value: $configuration.fadeStart, range: 0 ... 0.8, format: "%.2f")
                }

                Section("Dissolve") {
                    parameterSlider("Duration", value: $configuration.dissolveDuration, range: 0.1 ... 0.9, format: "%.2f")
                    parameterSlider("Edge width", value: $configuration.dissolveEdgeWidth, range: 0.02 ... 0.25, format: "%.2f")
                    parameterSlider("Cell scale", value: $configuration.dissolveCellScale, range: 0.2 ... 1, format: "%.2f")
                }

                Button("Reset Defaults") {
                    configuration = CardCastEffectConfiguration()
                    particleCount = 50
                    duration = 1
                    keyword = .burn
                    playbackStart = Date()
                }
            }
            .frame(width: 340)
        }
    }

    private func progress(at date: Date) -> CGFloat {
        guard playsAutomatically else { return scrubProgress }
        let elapsed = max(0, date.timeIntervalSince(playbackStart))
        return CGFloat((elapsed / TimeInterval(duration)).truncatingRemainder(dividingBy: 1))
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }
}

#Preview("Card Cast Effect Lab") {
    CardCastEffectPlayground()
}
#endif
