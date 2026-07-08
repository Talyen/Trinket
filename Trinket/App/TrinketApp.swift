import SwiftUI

@main
struct TrinketApp: App {
    @State private var appState = AppState(environment: .shared)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
