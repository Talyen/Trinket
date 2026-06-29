import SwiftUI

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let battleHealth: Int?
    let headerHeight: CGFloat
    let stretch: CGFloat
    let containerWidth: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CombatantArtwork(combatant: combatant)
                .aspectRatio(contentMode: .fill)
                .frame(width: containerWidth, height: headerHeight + stretch, alignment: .top)
                .clipped()
                .offset(y: -stretch)

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
        }
        .frame(height: headerHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name), \(combatant.role.rawValue), level \(progression.level), \(currentHealth) of \(combatant.maxHealth) health")
    }

    private var currentHealth: Int {
        battleHealth ?? combatant.maxHealth
    }
}
