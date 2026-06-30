import SwiftUI

struct CombatantHeroHeader: View {
    let combatant: Combatant
    let progression: CombatantProgression
    let baseHeight: CGFloat
    let coordinateSpaceName: String
    var body: some View {
        GeometryReader { geometry in
            let pullDistance = max(geometry.frame(in: .named(coordinateSpaceName)).minY, 0)
            let scale = HeroHeaderLayout.overscrollScale(baseHeight: baseHeight, pullDistance: pullDistance)

            ZStack(alignment: .topLeading) {
                CombatantArtwork(combatant: combatant)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(scale, anchor: .top)

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
            .frame(height: baseHeight + pullDistance)
            .clipped()
            .offset(y: -pullDistance)
        }
        .frame(height: baseHeight)
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
