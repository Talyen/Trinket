import SwiftUI

extension View {
    func trinketDetailSheet() -> some View {
        presentationDetents([.large])
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
    }
}
