import SwiftUI
import TrinketAppState

struct HiddenTabPrewarm: View {
    let appState: AppState
    var onFirstLayout: () -> Void = {}

    var body: some View {
        ZStack {
            NavigationStack {
                CollectionView()
            }
            NavigationStack {
                HomesteadView()
            }
            NavigationStack {
                makeOptionsView(appState: appState)
            }
        }
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await Task.yield()
            await Task.yield()
            guard !Task.isCancelled else { return }
            onFirstLayout()
        }
    }
}
