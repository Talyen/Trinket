import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem


struct BattleCombatantPane: View {
    enum HealthBarPlacement {
        case top
        case bottom
    }

    let configuration: BattleCombatantPaneConfiguration
    let reduceMotion: Bool
    let onCombatantTap: () -> Void

    private var combatant: Combatant {
        configuration.combatant
    }

    var body: some View {
        Button(action: onCombatantTap) {
            ZStack {
                CombatantArtwork(combatant: combatant, variant: .battle)

                healthScrim

                healthBar

                CombatFeedbackOverlay(
                    events: configuration.events,
                    reduceMotion: reduceMotion
                )
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketCardSurface()
            .contentShape(TrinketDesign.cardShape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(combatant.name) card")
            .accessibilityValue(healthText)
            .accessibilityHint("Shows details")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var healthText: String {
        if configuration.hasMana {
            return "\(configuration.health)/\(configuration.maxHealth) HP \(configuration.mana)/\(configuration.maxMana) MP"
        }
        return "\(configuration.health)/\(configuration.maxHealth) HP"
    }

    private var healthBar: some View {
        healthChrome {
            if configuration.hasMana {
                HStack(spacing: 4) {
                    CombatHealthBar(
                        health: configuration.health,
                        maxHealth: configuration.maxHealth,
                        fillColor: combatant.healthBarColor
                    )

                    CombatManaBar(
                        mana: configuration.mana,
                        maxMana: configuration.maxMana
                    )
                }
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                CombatHealthBar(
                    health: configuration.health,
                    maxHealth: configuration.maxHealth,
                    fillColor: combatant.healthBarColor
                )
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private var healthScrim: some View {
        healthChrome {
            LinearGradient(
                // UIStyleCheck: allow - battle health bars need readable contrast over full-bleed art.
                colors: [Color.black.opacity(0.42), .clear],
                startPoint: configuration.healthBarPlacement == .top ? .top : .bottom,
                endPoint: configuration.healthBarPlacement == .top ? .bottom : .top
            )
            .frame(height: 54)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func healthChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            if configuration.healthBarPlacement == .bottom {
                Spacer(minLength: 0)
            }

            content()

            if configuration.healthBarPlacement == .top {
                Spacer(minLength: 0)
            }
        }
    }
}

struct CombatManaBar: View {
    let mana: Int
    let maxMana: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(Keyword.mana.visualStyle.color)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: TrinketDesign.Metrics.statBarHeight)
        .clipShape(Capsule())
    }

    private var fraction: Double {
        guard maxMana > 0 else { return 0 }
        return min(max(Double(mana) / Double(maxMana), 0), 1)
    }
}
