import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

/// Traveling card-border shine for persistent buff auras (e.g. Shadowstep).
struct CombatantBuffAuraBorder: View {
    let kind: CombatantBuffAuraKind
    var isMotionActive: Bool = true

    private var motionEnabled: Bool {
        isMotionActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionEnabled)) { context in
            CombatantBuffAuraStroke(
                kind: kind,
                angle: motionEnabled
                    ? TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
                    : 0
            )
        }
        .allowsHitTesting(false)
    }
}

private struct CombatantBuffAuraStroke: View {
    let kind: CombatantBuffAuraKind
    let angle: Double

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
        case .predatorsFocus:
            // Physical keyword amber/orange is the Predator's Focus shimmer palette.
            let style = Keyword.physical.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.95))
        case .glacialWard:
            // Freeze keyword cyan is the Glacial Ward shimmer palette.
            let style = Keyword.freeze.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.95))
        case .thorns:
            // Poison keyword emerald green is the Thorns shimmer palette.
            let style = Keyword.poison.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.92))
        case .avatar:
            // Gold keyword gold is the Avatar shimmer palette.
            let style = Keyword.gold.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.95))
        case .marked:
            // Death's door crimson amber is the Marked vulnerability shimmer palette.
            let style = Keyword.deathsDoor.visualStyle
            return (style.color, TrinketDesign.Colors.Overlay.paper.opacity(0.95))
        case .blizzard:
            // Freeze keyword ice cyan is the Blizzard shimmer palette.
            let style = Keyword.freeze.visualStyle
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
