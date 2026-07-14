import SwiftUI

extension View {
    func trinketDetailSheet(dragIndicator: Visibility = .visible) -> some View {
        presentationDetents([.large])
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(dragIndicator)
    }
}
