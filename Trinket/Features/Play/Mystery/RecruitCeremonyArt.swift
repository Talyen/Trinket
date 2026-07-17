import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Mystery stage art (breathing shroud) crossfading into clear recruit portrait.
struct RecruitCeremonyArt: View {
    let stage: Stage
    let combatant: Combatant
    /// 0 = invitation shroud, 1 = clear recruit art.
    var clearAmount: CGFloat
    var isBreathingEnabled: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: clearAmount >= 0.999)) { context in
            let breath = invitationBreath(at: context.date)
            let shroud = max(0, 1 - clearAmount)
            let blur = TrinketMotion.RecruitReveal.invitationBlurRadius(breath: breath) * shroud
            let saturation = TrinketMotion.RecruitReveal.invitationSaturation(breath: breath)

            ZStack {
                EncounterArtwork(stage: stage)
                    .saturation(saturation)
                    .blur(radius: blur, opaque: false)
                    .opacity(shroud)

                CombatantArtwork(combatant: combatant, variant: .hero)
                    .opacity(clearAmount)
            }
        }
        .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .trinketArtworkBlend(.perimeter(into: .canvas))
    }

    private func invitationBreath(at date: Date) -> CGFloat {
        guard isBreathingEnabled, clearAmount < 1 else {
            // Mid-clear uses a settled mid breath so blur only scales with shroud.
            return 0.5
        }
        let cycle = TrinketMotion.RecruitReveal.breathCycleDuration
        guard cycle > 0 else { return 0.5 }
        let phase = date.timeIntervalSinceReferenceDate / cycle
        return CGFloat(0.5 + 0.5 * sin(phase * 2 * Double.pi))
    }
}
