import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Traveling card-border shine for persistent buff auras (e.g. Shadowstep).
struct CombatantBuffAuraBorder: View {
    let kind: CombatantBuffAuraKind

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let period = TrinketMotion.Battle.buffAuraShimmerPeriod
            let unit = period > 0 ? elapsed / period : 0
            stroke(progress: CGFloat(unit))
        }
        .onChange(of: kind) { _, _ in
            startDate = Date()
        }
    }

    private func stroke(progress: CGFloat) -> some View {
        let style = palette(for: kind)
        let angle = Angle.degrees(Double(progress) * 360)
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
                    angle: angle
                ),
                lineWidth: 2
            )
            .shadow(color: style.glow.opacity(0.55), radius: 3, x: 0, y: 0)
            .allowsHitTesting(false)
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
