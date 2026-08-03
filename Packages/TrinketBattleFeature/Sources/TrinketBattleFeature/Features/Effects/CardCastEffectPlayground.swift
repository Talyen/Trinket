import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
private struct CardCastEffectPlayground: View {
    private let cardSize = CGSize(width: 168, height: 224)

    @State private var configuration = CardCastEffectConfiguration()
    @State private var particleCount = 20
    @State private var duration: CGFloat = 1.0
    @State private var scrubProgress: CGFloat = 0.18
    @State private var playsAutomatically = false
    @State private var playbackStart = Date()
    @State private var keyword = Keyword.burn

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.animation(paused: !playsAutomatically)) { timeline in
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
                    parameterSlider("Fade start variation", value: $configuration.fadeStartVariation, range: 0 ... 0.6, format: "%.2f")
                }

                Section("Motion Falloff") {
                    parameterSlider("Age ease power", value: $configuration.particleAgeEasePower, range: 0.5 ... 4, format: "%.2f")
                    parameterSlider("Size shrink", value: $configuration.particleSizeShrink, range: 0 ... 1, format: "%.2f")
                    parameterSlider("Fade exponent", value: $configuration.particleFadeExponent, range: 0.4 ... 3, format: "%.2f")
                    parameterSlider("Path control", value: $configuration.particlePathControl, range: 0 ... 1, format: "%.2f")
                }

                Section("Dissolve") {
                    parameterSlider("Duration", value: $configuration.dissolveDuration, range: 0.1 ... 0.9, format: "%.2f")
                    parameterSlider("Shrink", value: $configuration.dissolveShrink, range: 0 ... 0.25, format: "%.2f")
                    parameterSlider("Edge depth weight", value: $configuration.dissolveEdgeDepthWeight, range: 0 ... 1.5, format: "%.2f")
                    parameterSlider("Noise weight", value: $configuration.dissolveNoiseWeight, range: 0 ... 1, format: "%.2f")
                    parameterSlider("Cell size", value: $configuration.dissolveCellSize, range: 1 ... 12, format: "%.0f px")
                    parameterSlider(
                        "Threshold midpoint",
                        value: $configuration.dissolveThresholdMidpoint,
                        range: 0.2 ... 0.8,
                        format: "%.2f"
                    )
                    parameterSlider(
                        "Threshold contrast",
                        value: $configuration.dissolveThresholdContrast,
                        range: 10 ... 200,
                        format: "%.0f"
                    )
                }

                Button("Reset Defaults") {
                    configuration = CardCastEffectConfiguration()
                    particleCount = 20
                    duration = 1
                    keyword = .burn
                    playbackStart = Date()
                }
            }
            .frame(width: 340)
        }
        .preferredColorScheme(.dark)
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

struct CardCastEffectLab_Previews: PreviewProvider {
    static var previews: some View {
        CardCastEffectPlayground()
            .preferredColorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro 13-inch (M5)"))
            .previewInterfaceOrientation(.landscapeLeft)
            .previewDisplayName("Card Cast Effect Lab")
    }
}
#endif
