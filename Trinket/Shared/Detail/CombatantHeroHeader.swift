import SwiftUI
import TrinketContent
import TrinketCore

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let baseHeight: CGFloat
    let overscroll: CGFloat
    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading
        ) {
            CombatantArtwork(combatant: combatant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                VStack(alignment: .leading) {
                    titleBlock
                    experienceFooter
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(combatant.name), \(combatant.role.rawValue), level \(progression.level), \(progression.currentXP) of \(progression.requiredXP) experience"
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading) {
            Text(combatant.role.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))

            Text(combatant.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private var experienceFooter: some View {
        HStack {
            Text("LEVEL \(progression.level)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))

            Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
