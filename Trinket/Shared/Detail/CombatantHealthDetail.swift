import SwiftUI

struct ExperienceProgressDetail: View {
    let progression: CombatantProgression

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("\(progression.currentXP)/\(progression.requiredXP) XP") {
                Text("\(Int(progression.progressFraction * 100))%")
                    .font(.footnote.monospacedDigit().weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.progression)
            }

            ProgressView(value: progression.progressFraction)
                .tint(TrinketDesign.Colors.progression)
                .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

struct CombatantHealthDetail: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(health), total: Double(maxHealth))
                .tint(fillColor)
                .frame(maxWidth: .infinity)

            Text("\(health)/\(maxHealth) HP")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}
