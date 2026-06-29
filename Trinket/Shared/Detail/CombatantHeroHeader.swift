import SwiftUI

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let battleHealth: Int?

    var body: some View {
        CombatantArtwork(combatant: combatant)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(combatant.role.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(combatant.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 12) {
                        Text("Level \(progression.level)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("\(currentHealth)/\(combatant.maxHealth) HP")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .safeAreaPadding(.bottom)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(combatant.name), \(combatant.role.rawValue), level \(progression.level), \(currentHealth) of \(combatant.maxHealth) health")
    }

    private var currentHealth: Int {
        battleHealth ?? combatant.maxHealth
    }
}
