import SwiftUI
import TrinketDesignSystem

struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        ZStack {
            TrinketDesign.Colors.appBackground
                .ignoresSafeArea()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
