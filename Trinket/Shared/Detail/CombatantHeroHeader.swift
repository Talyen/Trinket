import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

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
                TrinketHeroScrim.gradient(for: .detailHeader)
                    .frame(height: HeroHeaderLayout.scrimHeight)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(combatant.role.rawValue.uppercased())
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text(combatant.name)
                .trinketTypography(.screenDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private var experienceFooter: some View {
        HStack {
            Text("LEVEL \(progression.level)")
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                .trinketTypography(.eyebrow)
                .monospacedDigit()
                .trinketOnArtText(.eyebrow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
