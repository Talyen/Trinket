import SwiftUI

struct HiddenTabPrewarm: View {
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
                OptionsView()
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
