import SwiftUI

struct CombatFeedbackOverlay: View {
    let items: [CombatFeedbackItem]
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                CombatFeedbackEventView(
                    item: item,
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
