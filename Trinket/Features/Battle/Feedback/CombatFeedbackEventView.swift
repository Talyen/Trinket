import SwiftUI

struct CombatFeedbackEventView: View {
    let event: ActionEvent
    let stackIndex: Int
    let reduceMotion: Bool

    @State private var rmOpacity = 0.0

    var body: some View {
        if reduceMotion {
            feedbackLabel
                .opacity(rmOpacity)
                .offset(y: CGFloat(stackIndex) * CombatFeedbackTiming.stackSpacing)
                .task(id: event.id) {
                    withAnimation(.easeOut(duration: CombatFeedbackTiming.reduceMotionFadeIn)) {
                        rmOpacity = 1.0
                    }
                    try? await Task.sleep(for: .seconds(CombatFeedbackTiming.reduceMotionHold))
                    withAnimation(.easeOut(duration: CombatFeedbackTiming.reduceMotionFadeOut)) {
                        rmOpacity = 0.0
                    }
                }
        } else {
            KeyframeAnimator(
                initialValue: CombatFeedbackAnimationState(),
                trigger: event.id
            ) { state in
                feedbackLabel
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
                    .offset(y: state.verticalOffset + CGFloat(stackIndex) * CombatFeedbackTiming.stackSpacing)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.1, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.24)
                    SpringKeyframe(0.98, duration: 0.55)
                }

                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1.0, duration: 0.18)
                    CubicKeyframe(1.0, duration: 0.52)
                    CubicKeyframe(0.0, duration: 0.25)
                }

                KeyframeTrack(\.verticalOffset) {
                    SpringKeyframe(-8, duration: 0.16)
                    SpringKeyframe(-34, duration: 0.58)
                    SpringKeyframe(-48, duration: 0.21)
                }
            }
        }
    }

    private var feedbackLabel: some View {
        let display = ActionEventFormatter.display(for: event)
        let style = display.feedbackVisualStyle
        return HStack(spacing: 6) {
            Image(systemName: style.symbolName)
                .font(.caption.bold())
                .symbolEffect(.bounce, value: event.id)

            Text(display.text)
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // UIStyleCheck: allow - combat feedback is transient floating battle chrome.
        .glassEffect(.regular)
        .clipShape(Capsule())
    }
}

struct CombatFeedbackAnimationState {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
}

private extension ActionEventDisplay {
    var feedbackVisualStyle: Keyword.VisualStyle {
        switch emphasis {
        case .heal:
            return .health
        case .resourceGain:
            return .gold
        case .shieldAbsorbed:
            return .block
        case .dodge:
            return Keyword.dodge.visualStyle
        case .control:
            return .stun
        default:
            return keyword.visualStyle
        }
    }
}
