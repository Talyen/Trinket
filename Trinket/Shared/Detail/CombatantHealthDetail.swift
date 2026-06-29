import SwiftUI

struct CombatantHealthDetail: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()

                Text("\(health)/\(maxHealth) HP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            CombatHealthBar(
                health: health,
                maxHealth: maxHealth,
                fillColor: fillColor
            )
                .accessibilityLabel("Health")
                .accessibilityValue("\(health) of \(maxHealth) HP")
        }
        .padding(.vertical, 4)
    }
}

struct CombatHealthBar: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    @State private var displayedHealth: Double
    @State private var trailingHealth: Double
    @State private var restoreHealth: Double
    @State private var restoreOpacity = 0.0

    init(health: Int, maxHealth: Int, fillColor: Color) {
        self.health = health
        self.maxHealth = maxHealth
        self.fillColor = fillColor
        let initialHealth = Double(health)
        _displayedHealth = State(initialValue: initialHealth)
        _trailingHealth = State(initialValue: initialHealth)
        _restoreHealth = State(initialValue: initialHealth)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

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
        .frame(height: TrinketDesign.Metrics.statBarHeight)
        .clipShape(Capsule())
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
