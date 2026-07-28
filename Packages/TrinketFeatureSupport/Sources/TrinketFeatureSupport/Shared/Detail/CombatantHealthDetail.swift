import SwiftUI
import TrinketDesignSystem

public struct CombatHealthBar: View {
    public enum Style {
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

    @State private var displayedHealth: Double
    @State private var trailingHealth: Double
    @State private var restoreHealth: Double
    @State private var restoreOpacity = 0.0

    public init(
        health: Int,
        maxHealth: Int,
        fillColor: Color,
        style: Style = .standard,
        height: CGFloat = TrinketDesign.Metrics.statBarHeight
    ) {
        self.health = health
        self.maxHealth = maxHealth
        self.fillColor = fillColor
        self.style = style
        self.height = height
        let initialHealth = Double(health)
        _displayedHealth = State(initialValue: initialHealth)
        _trailingHealth = State(initialValue: initialHealth)
        _restoreHealth = State(initialValue: initialHealth)
    }

    public var body: some View {
        Group {
            switch style {
            case .standard:
                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack(alignment: .leading) {
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
                    }
                }
            case .battleBorder:
                // Avoid GeometryReader here — its width can collapse to ~0 when this
                // strip is overlaid on landscape battle panes.
                ZStack(alignment: .leading) {
                    Rectangle().fill(TrinketDesign.Colors.battleHealthTrack)
                    Rectangle()
                        .fill(TrinketDesign.Colors.healthRestore)
                        .opacity(restoreOpacity)
                        .scaleEffect(x: restoreFraction, y: 1, anchor: .leading)
                    Rectangle()
                        .fill(TrinketDesign.Colors.battleHealthTrailingDamage)
                        .scaleEffect(x: trailingFraction, y: 1, anchor: .leading)
                    Rectangle()
                        .fill(fillColor)
                        .scaleEffect(x: displayedFraction, y: 1, anchor: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
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

        if newValue < oldValue {
            withAnimation(TrinketMotion.Content.fade) {
                displayedHealth = newHealth
                restoreOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                trailingHealth = newHealth
            }
        } else if newValue > oldValue {
            restoreHealth = newHealth
            restoreOpacity = 0.85
            withAnimation(TrinketMotion.Content.fade) {
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
