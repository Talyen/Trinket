import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatantVitalBarsView: View, Equatable {
    let combatBuild: CombatBuild
    let combatantRole: Combatant.Role
    let battleHealth: Int?
    let battleMana: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
                DetailVitalBar(
                    label: "Health",
                    value: battleHealth ?? combatBuild.effectiveMaxHealth,
                    maxValue: combatBuild.effectiveMaxHealth,
                    fillColor: TrinketDesign.Colors.health,
                    accessibilityID: AccessibilityID.CombatantDetail.healthBar,
                )

                if combatantRole != .enemy, combatBuild.effectiveMaxMana > 0 {
                    DetailVitalBar(
                        label: "Mana",
                        value: battleMana ?? combatBuild.effectiveMaxMana,
                        maxValue: combatBuild.effectiveMaxMana,
                        fillColor: Keyword.mana.visualStyle.color,
                        accessibilityID: AccessibilityID.CombatantDetail.manaBar,
                    )
                }
            }
            .trinketSurface(.secondary)
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.top, TrinketDesign.Layout.contentTopPadding)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.vitalBarsSection)
    }
}

private struct DetailVitalBar: View {
    let label: String
    let value: Int
    let maxValue: Int
    let fillColor: Color
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            HStack {
                Text(label)
                    .trinketTypography(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: TrinketDesign.Spacing.small)

                Text("\(value)/\(maxValue)")
                    .trinketTypography(.statValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(TrinketMotion.Interaction.selection, value: value)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label), \(value) of \(maxValue)")
            .accessibilityAddTraits(.isStaticText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: TrinketDesign.Bars.vitalHeight)
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.35), value: value)
            .animation(.easeOut(duration: 0.35), value: maxValue)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(Double(value) / Double(maxValue), 0), 1)
    }
}
