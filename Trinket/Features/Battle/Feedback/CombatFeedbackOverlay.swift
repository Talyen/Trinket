import SwiftUI

struct CombatFeedbackOverlay: View {
    let items: [CombatFeedbackItem]
    let reduceMotion: Bool

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                TimelineView(.animation(paused: false)) { context in
                    let visible = items.filter { item in
                        context.date >= item.availableAt && context.date < item.expiresAt
                    }
                    ZStack {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                            CombatFeedbackEventView(
                                item: item,
                                stackIndex: index,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
