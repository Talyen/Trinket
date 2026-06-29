import SwiftUI

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let baseHeight: CGFloat
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { geometry in
            let pullDistance = max(geometry.frame(in: .named(coordinateSpaceName)).minY, 0)

            ZStack(alignment: .bottomLeading) {
                CombatantArtwork(combatant: combatant)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: baseHeight + pullDistance, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading) {
                    titleBlock
                    experienceFooter
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: baseHeight + pullDistance)
            .offset(y: -pullDistance)
        }
        .frame(height: baseHeight)
        .clipped()
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
            Text("Level \(progression.level)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
