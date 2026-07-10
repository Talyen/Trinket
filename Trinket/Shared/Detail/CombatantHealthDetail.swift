import SwiftUI
import TrinketDesignSystem

struct CombatHealthBar: View {
    enum Style {
        /// Capsule bar used for general combatant detail chrome.
        case standard
        /// Full-bleed rectangular strip for battle card bottom-edge chrome.
        case battleBorder
    }

    let health: Int
    let maxHealth: Int
    let fillColor: Color
    var style: Style = .standard
    var height: CGFloat = TrinketDesign.Metrics.statBarHeight
    var reduceMotion: Bool = false

    @State private var displayedHealth: Double
    @State private var trailingHealth: Double
    @State private var restoreHealth: Double
    @State private var restoreOpacity = 0.0

    init(
        health: Int,
        maxHealth: Int,
        fillColor: Color,
        style: Style = .standard,
        height: CGFloat = TrinketDesign.Metrics.statBarHeight,
        reduceMotion: Bool = false
    ) {
        self.health = health
        self.maxHealth = maxHealth
        self.fillColor = fillColor
        self.style = style
        self.height = height
        self.reduceMotion = reduceMotion
        let initialHealth = Double(health)
        _displayedHealth = State(initialValue: initialHealth)
        _trailingHealth = State(initialValue: initialHealth)
        _restoreHealth = State(initialValue: initialHealth)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                switch style {
                case .standard:
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(TrinketDesign.Colors.healthRestore)
                        .frame(width: width * restoreFraction)
                        .opacity(restoreOpacity)
                    Capsule()
                        .fill(TrinketDesign.Colors.healthTrailingDamage)
                        .frame(width: width * trailingFraction)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: width * displayedFraction)
                case .battleBorder:
                    Rectangle().fill(TrinketDesign.Colors.battleHealthTrack)
                    Rectangle()
                        .fill(TrinketDesign.Colors.healthRestore)
                        .frame(width: width * restoreFraction)
                        .opacity(restoreOpacity)
                    Rectangle()
                        .fill(TrinketDesign.Colors.battleHealthTrailingDamage)
                        .frame(width: width * trailingFraction)
                    Rectangle()
                        .fill(fillColor)
                        .frame(width: width * displayedFraction)
                }
            }
        }
        .frame(height: height)
        .modifier(CombatHealthBarClipModifier(style: style))
        .onChange(of: health) { oldValue, newValue in
            animateHealthChange(from: oldValue, to: newValue)
        }
    }

    private var displayedFraction: Double {
        healthFraction(displayedHealth)
    }

    private var trailingFraction: Double {
        healthFraction(trailingHealth)
    }

    private var restoreFraction: Double {
        healthFraction(restoreHealth)
    }

    private func healthFraction(_ value: Double) -> Double {
        guard maxHealth > 0 else { return 0 }
        return min(max(value / Double(maxHealth), 0), 1)
    }

    private func animateHealthChange(from oldValue: Int, to newValue: Int) {
        let newHealth = Double(newValue)

        if reduceMotion {
            displayedHealth = newHealth
            trailingHealth = newHealth
            restoreHealth = newHealth
            restoreOpacity = 0
            return
        }

        if newValue < oldValue {
            withAnimation(.easeOut(duration: 0.22)) {
                displayedHealth = newHealth
                restoreOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                trailingHealth = newHealth
            }
        } else if newValue > oldValue {
            restoreHealth = newHealth
            restoreOpacity = 0.85
            withAnimation(.easeOut(duration: 0.22)) {
                displayedHealth = newHealth
                trailingHealth = newHealth
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.18)) {
                restoreOpacity = 0
            }
        } else {
            displayedHealth = newHealth
            trailingHealth = newHealth
            restoreHealth = newHealth
        }
    }
}

private struct CombatHealthBarClipModifier: ViewModifier {
    let style: CombatHealthBar.Style

    func body(content: Content) -> some View {
        switch style {
        case .standard:
            content.clipShape(Capsule())
        case .battleBorder:
            content.clipShape(Rectangle())
        }
    }
}
