import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketFeatureSupport

/// Last-resort launch UI when even in-memory AppState bootstrap fails.
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
