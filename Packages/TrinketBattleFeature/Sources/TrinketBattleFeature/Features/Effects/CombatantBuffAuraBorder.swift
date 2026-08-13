import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Traveling card-border shine for persistent buff auras (e.g. Shadowstep).
struct CombatantBuffAuraBorder: View {
    let kind: CombatantBuffAuraKind
    var isMotionActive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerAngle = 0.0

    private var motionEnabled: Bool {
        isMotionActive && !reduceMotion
    }

    var body: some View {
        CombatantBuffAuraStroke(kind: kind, angle: shimmerAngle)
            .onAppear {
                startShimmerIfNeeded()
            }
            .onChange(of: motionEnabled) { _, active in
                if active {
                    startShimmerIfNeeded()
                } else {
                    var freeze = Transaction()
                    freeze.disablesAnimations = true
                    withTransaction(freeze) {
                        shimmerAngle = shimmerAngle.truncatingRemainder(dividingBy: 360)
                    }
                }
            }
            .allowsHitTesting(false)
    }

    private func startShimmerIfNeeded() {
        guard motionEnabled else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            shimmerAngle = 0
        }
        withAnimation(
            .linear(duration: TrinketMotion.Battle.buffAuraShimmerPeriod).repeatForever(autoreverses: false)
        ) {
            shimmerAngle = 360
        }
    }
}

private struct CombatantBuffAuraStroke: View, Animatable {
    let kind: CombatantBuffAuraKind
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let style = palette(for: kind)
        TrinketDesign.cardShape.strokeBorder(
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: style.base.opacity(0.22), location: 0),
                    .init(color: style.base.opacity(0.65), location: 0.28),
                    .init(color: style.highlight, location: 0.4),
                    .init(color: style.base.opacity(0.9), location: 0.5),
                    .init(color: style.base.opacity(0.28), location: 0.72),
                    .init(color: style.base.opacity(0.22), location: 1),
                ]),
                center: .center,
                angle: .degrees(angle)
            ),
            lineWidth: 2
        )
    }

    private func palette(for kind: CombatantBuffAuraKind) -> (base: Color, highlight: Color) {
        switch kind {
        case .shadowstep:
            // Purge keyword purple is the Shadowstep shimmer palette.
            let style = Keyword.purge.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.92))
        case .avatar:
            // Gold keyword gold is the Avatar shimmer palette.
            let style = Keyword.gold.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.95))
        }
    }
}

/// Isolates spectacle observation so hit-reaction KeyframeAnimator does not rebuild
/// when cinematics or outcome chrome start.
struct CombatantBuffAuraLane: View {
    @Environment(BattleSession.self) private var battleSession
    let kind: CombatantBuffAuraKind

    var body: some View {
        CombatantBuffAuraBorder(
            kind: kind,
            isMotionActive: battleSession.spectacle.activeCinematic == nil
                && !battleSession.spectacle.isShowingVictory
                && !battleSession.spectacle.isShowingDefeat
        )
    }
}
