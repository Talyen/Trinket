import SwiftUI
import TrinketPersistence

@main
struct TrinketApp: App {
    @State private var appState: AppState

    init() {
        do {
            _appState = try State(initialValue: AppState(environment: .shared))
        } catch {
            assertionFailure("AppState bootstrap failed: \(error)")
            _appState = State(initialValue: try! AppState(
                environment: .shared,
                playerSave: try! PlayerSaveStore(inMemoryOnly: true),
                shellSessionStore: try! PlayerShellSessionStore(inMemoryOnly: true)
            ))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
