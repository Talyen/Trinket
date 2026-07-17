#if DEBUG
import SwiftUI
import TrinketContent
import TrinketDesignSystem

enum RecruitRevealLabPhase: Equatable {
    case invitation
    case revealing
    case complete
}

/// Breathing mystery-art → clear recruit preview for the motion lab.
struct RecruitRevealEffectPreview: View {
    let stage: Stage
    let combatant: Combatant
    let phase: RecruitRevealLabPhase
    let progress: CGFloat
    let showsShellChrome: Bool
    let onInviteTap: () -> Void

    @State private var inviteTapTrigger = 0

    private var eyebrow: String {
        combatant.role == .companion ? "New Companion" : "New Hero"
    }

    private var isInviting: Bool {
        phase == .invitation
    }

    private var clearAmount: CGFloat {
        guard !isInviting else { return 0 }
        let motion = TrinketMotion.RecruitReveal.self
        return recruitRevealSmoothstep(
            recruitRevealRemap(progress, from: motion.clearStart ... motion.clearEnd)
        )
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
            if showsShellChrome {
                chromeHeader
            }

            Group {
                if isInviting {
                    invitationTarget
                } else {
                    ceremonyArt
                }
            }
            .frame(maxWidth: 420)

            if showsShellChrome {
                chromeFooter
            }
        }
    }

    private var invitationTarget: some View {
        Button {
            inviteTapTrigger += 1
            onInviteTap()
        } label: {
            ceremonyArt
                .contentShape(TrinketDesign.cardShape)
        }
        // UIStyleCheck: allow - Invitation is the portrait itself; no button chrome.
        .trinketQuietTapButtonStyle()
        .sensoryFeedback(.selection, trigger: inviteTapTrigger)
    }

    private var ceremonyArt: some View {
        RecruitCeremonyArt(
            stage: stage,
            combatant: combatant,
            clearAmount: clearAmount,
            isBreathingEnabled: isInviting
        )
    }

    private var chromeHeader: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            Text(eyebrow)
                .trinketTypography(.eyebrow)
                .foregroundStyle(TrinketDesign.Colors.accent)
                .textCase(.uppercase)
                .opacity(isInviting ? 0 : recruitRevealChromeOpacity(progress, start: 0.55, end: 0.7))

            Text(combatant.name)
                .trinketTypography(.screenDisplay)
                .multilineTextAlignment(.center)
                .opacity(isInviting ? 0 : recruitRevealChromeOpacity(progress, start: 0.65, end: 0.8))

            Text("UNLOCKED")
                .trinketTypography(.secondaryBody)
                .foregroundStyle(.secondary)
                .opacity(isInviting ? 0 : recruitRevealChromeOpacity(progress, start: 0.75, end: 0.9))
        }
    }

    private var chromeFooter: some View {
        Button {
            // Preview-only chrome; no action.
        } label: {
            Text("Recruit")
                .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton()
        .opacity(isInviting ? 0 : recruitRevealChromeOpacity(progress, start: 0.88, end: 1.0))
        .frame(maxWidth: 220)
        .disabled(true)
    }
}

func recruitRevealRemap(_ value: CGFloat, from range: ClosedRange<CGFloat>) -> CGFloat {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    return min(1, max(0, (value - range.lowerBound) / span))
}

func recruitRevealSmoothstep(_ t: CGFloat) -> CGFloat {
    let x = min(1, max(0, t))
    return x * x * (3 - 2 * x)
}

func recruitRevealChromeOpacity(_ progress: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
    recruitRevealSmoothstep(recruitRevealRemap(progress, from: start ... end))
}
#endif
