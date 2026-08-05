import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG
// DEBUG playground only — lab death variant picker. Do not ship lab UI.

enum CombatantDeathEffectKind: String, CaseIterable, Identifiable {
    case slice
    case dissolveBaseline

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .slice: "Slice"
        case .dissolveBaseline: "Dissolve Baseline"
        }
    }
}

struct CombatantDeathEffectConfig: Equatable {
    var intensity: CGFloat = 1
    var particleCount: Int = 24
    var tintStrength: CGFloat = 0.2
    var speed: CGFloat = 1

    /// Separation between halves as a fraction of card width.
    var splitGap: CGFloat = 0.22
    /// Hold before halves begin to separate (0…1 of the clip).
    var splitDelay: CGFloat = 0.18
    /// Celebrate dissolve with gold/holy fireworks (Dissolve Baseline).
    var celebrateDissolve = true

    static func defaults(for kind: CombatantDeathEffectKind) -> Self {
        var config = Self()
        switch kind {
        case .slice:
            config.intensity = 0.5
            config.splitGap = 0.22
            config.splitDelay = 0.2
            config.particleCount = 48
            config.tintStrength = 0.85
        case .dissolveBaseline:
            config.celebrateDissolve = true
            config.particleCount = 28
        }
        return config
    }

    var sliceConfig: CombatantSliceEffectConfig {
        CombatantSliceEffectConfig(
            intensity: intensity,
            particleCount: particleCount,
            tintStrength: tintStrength,
            speed: speed,
            splitGap: splitGap,
            splitDelay: splitDelay
        )
    }
}

struct CombatantDeathEffect<Content: View>: View {
    let kind: CombatantDeathEffectKind
    let config: CombatantDeathEffectConfig
    let progress: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch kind {
        case .slice:
            CombatantSliceEffect(
                config: config.sliceConfig,
                progress: progress,
                content: content
            )
        case .dissolveBaseline:
            GeometryReader { geometry in
                dissolveBaseline(size: geometry.size)
            }
            .allowsHitTesting(false)
        }
    }

    private var effectiveProgress: CGFloat {
        min(max(progress * config.speed, 0), 1)
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
#endif
