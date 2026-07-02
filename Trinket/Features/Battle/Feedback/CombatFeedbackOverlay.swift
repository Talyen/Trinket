import SwiftUI

struct CombatFeedbackOverlay: View {
    let events: [ActionEvent]
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                CombatFeedbackEventView(
                    event: event,
                    stackIndex: index,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
