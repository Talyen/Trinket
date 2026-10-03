import SwiftUI
import TrinketDesignSystem

#if DEBUG
enum BattleTransitionScreen { case picker, battle, victory }

enum BattleTransitionPreset: String, CaseIterable, Identifiable {
    case crossfade = "Crossfade"
    case push = "Push Through"
    case curtain = "Arcane Curtain"
    case iris = "Iris Reveal"

    var id: Self {
        self
    }

    var description: String {
        switch self {
        case .crossfade: "A quick dissolve between complete screens."
        case .push: "The stages recede as battle comes forward; returning reverses the depth."
        case .curtain: "An arcane curtain sweeps into battle and reverses on return, warming after victory."
        case .iris: "A circular opening reveals battle; battle closes back onto the stages."
        }
    }

    func duration(entering: Bool) -> Double {
        switch self {
        case .crossfade: 0.28
        case .push: entering ? 0.42 : 0.36
        case .curtain: 0.55
        case .iris: entering ? 0.55 : 0.45
        }
    }
}

struct BattleTransitionLabLayer: ViewModifier, Animatable {
    let screen: BattleTransitionScreen
    let source: BattleTransitionScreen
    let destination: BattleTransitionScreen?
    let preset: BattleTransitionPreset
    var progress: Double
    let isInteractive: Bool
    let tint: Color

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TrinketDesign.Colors.canvas)
            .scaleEffect(scale)
            .mask {
                if destination != nil, preset == .iris, screen != .picker {
                    GeometryReader { geometry in
                        let diameter = hypot(geometry.size.width, geometry.size.height) + 4
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(irisScale)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                } else {
                    Rectangle()
                }
            }
            .overlay {
                if destination != nil, preset == .iris, screen != .picker,
                   screen == source || screen == destination {
                    GeometryReader { geometry in
                        let diameter = hypot(geometry.size.width, geometry.size.height) + 4
                        Circle()
                            .strokeBorder(tint, lineWidth: 2)
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(irisScale)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .trinketPresentationVisibility(
                destination == nil && screen == source && isInteractive,
                opacity: opacity,
            )
    }

    private var opacity: Double {
        guard let destination else { return screen == source ? 1 : 0 }
        guard screen == source || screen == destination else { return 0 }
        switch preset {
        case .crossfade, .push:
            return screen == source ? 1 - progress : progress
        case .curtain:
            return screen == (progress < 0.5 ? source : destination) ? 1 : 0
        case .iris:
            return 1
        }
    }

    private var scale: Double {
        guard let destination, preset == .push else { return 1 }
        let entering = destination == .battle
        if screen == source {
            return 1 + (entering ? -0.04 : 0.04) * progress
        }
        return 1 + (entering ? 0.04 : -0.04) * (1 - progress)
    }

    private var irisScale: Double {
        destination == .battle ? progress : 1 - progress
    }
}
#endif
