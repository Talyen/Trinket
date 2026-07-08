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
    let skillCallout: SkillCalloutPresentation?
    let reduceMotion: Bool
    let cinematicNamespace: Namespace.ID
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

                if let skillCallout {
                    SkillCalloutView(callout: skillCallout, reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                        .allowsHitTesting(false)
                }

                // Invisible source for Ultimate matched-geometry expand from this card.
                Color.clear
                    .frame(width: 1, height: 1)
                    .matchedGeometryEffect(
                        id: "ultimate-source-\(combatant.id)",
                        in: cinematicNamespace,
                        isSource: true
                    )
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
                        fillColor: combatant.healthBarColor,
                        reduceMotion: reduceMotion
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
                    fillColor: combatant.healthBarColor,
                    reduceMotion: reduceMotion
                )
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private var healthScrim: some View {
        healthChrome {
            BattleHealthScrimGradient(
                placement: healthBarPlacement == .top ? .top : .bottom
            )
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
