import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Traveling card-border shine for persistent buff auras (e.g. Shadowstep).
struct CombatantBuffAuraBorder: View {
    let kind: CombatantBuffAuraKind

    @State private var shimmerAngle = 0.0

    var body: some View {
        CombatantBuffAuraStroke(kind: kind, angle: shimmerAngle)
            .onAppear {
                withAnimation(.linear(duration: TrinketMotion.Battle.buffAuraShimmerPeriod).repeatForever(autoreverses: false)) {
                    shimmerAngle = 360
                }
            }
            .allowsHitTesting(false)
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
        return TrinketDesign.cardShape
            .strokeBorder(
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
            .shadow(color: style.glow.opacity(0.55), radius: 3, x: 0, y: 0)
    }

    private func palette(for kind: CombatantBuffAuraKind) -> (
        base: Color,
        highlight: Color,
        glow: Color
    ) {
        switch kind {
        case .shadowstep:
            // Purge keyword purple is the Shadowstep shimmer palette.
            let style = Keyword.purge.visualStyle
            return (
                style.color,
                TrinketDesign.Colors.Overlay.paper.opacity(0.92),
                style.glowColor
            )
        case .avatar:
            // Gold keyword gold is the Avatar shimmer palette.
            let style = Keyword.gold.visualStyle
            return (
                style.color,
                TrinketDesign.Colors.Overlay.paper.opacity(0.95),
                style.glowColor
            )
        }
    }
}
