import SwiftUI
import TrinketAppState
import TrinketFeatureSupport

struct AppBootstrapFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Can't Open Trinket",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
}
