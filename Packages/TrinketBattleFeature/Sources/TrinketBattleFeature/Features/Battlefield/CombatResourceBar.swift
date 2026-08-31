import SwiftUI
import TrinketCore
import TrinketDesignSystem

package struct CombatResourceBar: View {
    package enum Style {
        case healthBattle
        case mana

        var trackColor: Color {
            TrinketDesign.Colors.battleHealthTrack
        }

        var fillColor: Color {
            switch self {
            case .healthBattle: TrinketDesign.Colors.battleHealth
            case .mana: Keyword.mana.visualStyle.color
            }
        }

        var height: CGFloat {
            TrinketDesign.Metrics.battleHealthBarHeight
        }

        var activeHeight: CGFloat {
            TrinketDesign.Metrics.battleHealthBarActiveHeight
        }

        func height(isActive: Bool) -> CGFloat {
            isActive ? activeHeight : height
        }

        var usesTrailing: Bool {
            switch self {
            case .healthBattle: true
            case .mana: false
            }
        }
    }

    let value: Int
    let maxValue: Int
    let style: Style
    let isActive: Bool

    @State private var displayed: Double
    @State private var trailing: Double
    @State private var restoreOpacity: Double = 0

    package init(value: Int, maxValue: Int, style: Style, isActive: Bool = false) {
        self.value = value
        self.maxValue = maxValue
        self.style = style
        self.isActive = isActive
        let initial = Double(value)
        _displayed = State(initialValue: initial)
        _trailing = State(initialValue: initial)
    }

    package var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(style.trackColor)
            if style.usesTrailing {
                Rectangle()
                    .fill(TrinketDesign.Colors.battleHealthTrailingDamage)
                    .scaleEffect(x: fraction(trailing), y: 1, anchor: .leading)
                Rectangle()
                    .fill(TrinketDesign.Colors.healthRestore)
                    .opacity(restoreOpacity)
                    .scaleEffect(x: fraction(trailing), y: 1, anchor: .leading)
            }
            Rectangle()
                .fill(style.fillColor)
                .scaleEffect(x: fraction(displayed), y: 1, anchor: .leading)
            if !style.usesTrailing, restoreOpacity > 0 {
                Rectangle()
                    .fill(style.fillColor)
                    .scaleEffect(x: fraction(displayed), y: 1, anchor: .leading)
                    .opacity(restoreOpacity)
                    .blendMode(.plusLighter)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: style.height(isActive: isActive))
        .clipShape(Rectangle())
        .animation(TrinketMotion.Interaction.stateChange, value: isActive)
        .onChange(of: value) { oldValue, newValue in
            animate(from: oldValue, to: newValue)
        }
        .onChange(of: maxValue) { _, _ in
            let target = Double(value)
            withAnimation(TrinketMotion.Content.fade) {
                displayed = target
                trailing = target
            }
        }
    }

    private func fraction(_ value: Double) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / Double(maxValue), 0), 1)
    }

    private func animate(from oldValue: Int, to newValue: Int) {
        let newDouble = Double(newValue)
        if newValue < oldValue {
            withAnimation(TrinketMotion.Content.fade) {
                displayed = newDouble
                restoreOpacity = 0
            }
            if style.usesTrailing {
                withAnimation(.easeOut(duration: 0.35).delay(0.12)) { trailing = newDouble }
            }
        } else if newValue > oldValue {
            if style.usesTrailing {
                trailing = newDouble
                restoreOpacity = 0.85
                withAnimation(TrinketMotion.Content.fade) {
                    displayed = newDouble
                }
                withAnimation(.easeOut(duration: 0.35).delay(0.18)) { restoreOpacity = 0 }
            } else {
                restoreOpacity = 0.36
                withAnimation(.easeOut(duration: TrinketMotion.Interaction.manaRestoreDuration)) {
                    displayed = newDouble
                    restoreOpacity = 0
                }
            }
        } else {
            displayed = newDouble
            trailing = newDouble
        }
    }
}
