import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct BattleCombatantPane: View {
    enum HealthBarPlacement {
        case top
        case bottom
    }

    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let healthBarPlacement: HealthBarPlacement
    let events: [ActionEvent]
    let reduceMotion: Bool
    let onCombatantTap: () -> Void

    private var hasMana: Bool {
        maxMana > 0
    }

    var body: some View {
        Button(action: onCombatantTap) {
            ZStack {
                CombatantArtwork(combatant: combatant, variant: .battle)

                healthScrim

                healthBar

                CombatFeedbackOverlay(
                    events: events,
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
        if hasMana {
            return "\(health)/\(maxHealth) HP \(mana)/\(maxMana) MP"
        }
        return "\(health)/\(maxHealth) HP"
    }

    private var healthBar: some View {
        healthChrome {
            if hasMana {
                HStack(spacing: 4) {
                    CombatHealthBar(
                        health: health,
                        maxHealth: maxHealth,
                        fillColor: combatant.healthBarColor
                    )

                    CombatManaBar(
                        mana: mana,
                        maxMana: maxMana
                    )
                }
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                CombatHealthBar(
                    health: health,
                    maxHealth: maxHealth,
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
                startPoint: healthBarPlacement == .top ? .top : .bottom,
                endPoint: healthBarPlacement == .top ? .bottom : .top
            )
            .frame(height: 54)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func healthChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            if healthBarPlacement == .bottom {
                Spacer(minLength: 0)
            }

            content()

            if healthBarPlacement == .top {
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
