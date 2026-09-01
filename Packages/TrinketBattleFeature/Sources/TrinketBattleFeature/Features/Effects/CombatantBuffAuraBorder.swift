import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatantBuffAuraBorder: View {
    let kind: CombatantBuffAuraKind
    var isMotionActive: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isMotionActive)) { context in
            CombatantBuffAuraStroke(
                kind: kind,
                angle: isMotionActive
                    ? TrinketMotion.Shine.phase(at: context.date.timeIntervalSinceReferenceDate) * 360
                    : 0,
            )
        }
        .allowsHitTesting(false)
    }
}

private struct CombatantBuffAuraStroke: View {
    let kind: CombatantBuffAuraKind
    let angle: Double

    var body: some View {
        let base = kind.keyword.visualStyle.color
        ZStack {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.panel, lineWidth: 2)
            TrinketDesign.cardShape.strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: base, location: 0),
                        .init(color: base, location: 0.28),
                        .init(color: TrinketDesign.Colors.Overlay.paper, location: 0.4),
                        .init(color: base, location: 0.5),
                        .init(color: base, location: 0.72),
                        .init(color: base, location: 1),
                    ]),
                    center: .center,
                    angle: .degrees(angle),
                ),
                lineWidth: 2,
            )
        }
        .compositingGroup()
        .shadow(color: base.opacity(0.4), radius: 8)
    }
}

private extension CombatantBuffAuraKind {
    var keyword: Keyword {
        switch self {
        case .shadowstep: .purge
        case .predatorsFocus: .physical
        case .glacialWard, .blizzard: .freeze
        case .moltenBulwark: .burn
        case .thorns: .poison
        case .avatar: .gold
        case .marked: .deathsDoor
        case .earthquake: .stun
        }
    }
}

struct CombatantBuffAuraLane: View {
    @Environment(BattleSession.self) private var battleSession
    let kind: CombatantBuffAuraKind

    var body: some View {
        CombatantBuffAuraBorder(
            kind: kind,
            isMotionActive: battleSession.lifecyclePhase == .active
                && !battleSession.spectacle.outcomePresentation.isOutcomePresented,
        )
    }
}
